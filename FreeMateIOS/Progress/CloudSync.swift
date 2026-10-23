import Combine
import Foundation

/// Keeps progress the same on every device signed in to the same iCloud account, with no
/// FreeMate account. Uses iCloud's key-value store, which needs the iCloud key-value storage
/// entitlement. Without it, or without iCloud, everything stays on the device.
///
/// Each synced store keeps writing to UserDefaults as before. Whenever UserDefaults changes, or
/// iCloud reports a change from another device, the local and cloud copies are merged with
/// `SyncMerge`, and both sides get the result.
@MainActor
final class CloudSync: ObservableObject {
    static let shared = CloudSync()
    static let deviceIdKey = "freemate.deviceId"
    static let computerDevicesKey = "freemate.computerGames.devices"
    static let otherDevicesComputerKey = "freemate.computerGames.otherDevices"

    /// Signed in to iCloud on this device.
    @Published private(set) var isAvailable = false
    @Published private(set) var lastSynced: Date?

    /// Called after another device's progress was merged in.
    var onRemoteChange: (() -> Void)?

    private let defaults: UserDefaults
    private let cloud = NSUbiquitousKeyValueStore.default
    private var observers: [NSObjectProtocol] = []
    private var pending: Task<Void, Never>?
    private var isApplying = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func start() {
        guard observers.isEmpty else { return }
        isAvailable = FileManager.default.ubiquityIdentityToken != nil
        observers.append(NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncNow(fromRemote: true) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSync() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSUbiquityIdentityDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.isAvailable = FileManager.default.ubiquityIdentityToken != nil }
        })
        cloud.synchronize()
        syncNow(fromRemote: true)
    }

    /// Batches bursts of local writes, such as one per move, into one sync.
    private func scheduleSync() {
        guard !isApplying else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.syncNow(fromRemote: false)
        }
    }

    func syncNow(fromRemote: Bool) {
        isApplying = true
        defer { isApplying = false }
        var localChanged = false
        for synced in SyncMerge.keys {
            let local = defaults.data(forKey: synced.key)
            let remote = cloud.data(forKey: synced.key)
            guard let merged = SyncMerge.merge(synced, local: local, cloud: remote) else { continue }
            if merged != local {
                defaults.set(merged, forKey: synced.key)
                localChanged = true
            }
            if merged != remote { cloud.set(merged, forKey: synced.key) }
        }
        syncComputerRecord()
        lastSynced = Date()
        if localChanged && fromRemote { onRemoteChange?() }
    }

    private func syncComputerRecord() {
        let own = defaults.data(forKey: ComputerGame.recordKey)
            .flatMap { try? JSONDecoder().decode(ComputerGameRecord.self, from: $0) } ?? ComputerGameRecord()
        let remote = cloud.data(forKey: Self.computerDevicesKey)
            .flatMap { try? JSONDecoder().decode([String: ComputerGameRecord].self, from: $0) } ?? [:]
        let result = SyncMerge.deviceRecords(own: own, cloud: remote, deviceId: deviceId)
        if result.cloud != remote, let data = try? JSONEncoder.progress.encode(result.cloud) {
            cloud.set(data, forKey: Self.computerDevicesKey)
        }
        if let data = try? JSONEncoder.progress.encode(result.others), data != defaults.data(forKey: Self.otherDevicesComputerKey) {
            defaults.set(data, forKey: Self.otherDevicesComputerKey)
        }
    }

    /// A random id for this install, never synced, so each device's games count once.
    private var deviceId: String {
        if let id = defaults.string(forKey: Self.deviceIdKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Self.deviceIdKey)
        return id
    }
}
