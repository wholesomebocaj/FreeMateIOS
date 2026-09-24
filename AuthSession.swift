import CryptoKit
import Foundation

struct FreeMateUser: Equatable, Identifiable {
    var id: Int
    var email: String?
    var username: String?
    var passwordHash: String
    var createdAt: String
    var updatedAt: String

    var displayName: String {
        if let username, !username.isEmpty { return "@\(username)" }
        return "Account"
    }
}

enum AuthError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

enum AuthSession {
    static let cookieName = "freemate_auth"
    static let maxAge = 60 * 60 * 24 * 30
    static let algorithm = "pbkdf2_sha256"
    static let iterations = 240_000
    private static let secret = "freemate-dev-session-secret"

    static func normalizeUsername(_ username: String) throws -> String {
        let value = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.isEmpty { throw AuthError.message("Choose a username.") }
        if value.count < 3 || value.count > 64 {
            throw AuthError.message("Username must be between 3 and 64 characters.")
        }
        if value.contains(where: { $0.isWhitespace }) {
            throw AuthError.message("Username cannot contain spaces.")
        }
        return value
    }

    static func hashPassword(_ password: String) throws -> String {
        if password.count < 8 {
            throw AuthError.message("Password must be at least 8 characters long.")
        }
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let digest = pbkdf2(password: Data(password.utf8), salt: salt, iterations: iterations)
        return [algorithm, "\(iterations)", b64(salt), b64(digest)].joined(separator: "$")
    }

    static func verifyPassword(_ password: String, storedHash: String) -> Bool {
        let parts = storedHash.split(separator: "$", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == algorithm, let iterations = Int(parts[1]) else { return false }
        guard let salt = b64Decode(parts[2]), let expected = b64Decode(parts[3]) else { return false }
        let candidate = pbkdf2(password: Data(password.utf8), salt: salt, iterations: iterations, length: expected.count)
        return constantTimeEquals(candidate, expected)
    }

    static func createCookie(userId: Int, issuedAt: Int = Int(Date().timeIntervalSince1970)) -> String {
        let payload = "{\"user_id\":\(userId),\"issued_at\":\(issuedAt)}"
        let payloadB64 = b64(Data(payload.utf8))
        return "\(payloadB64).\(sign(payloadB64))"
    }

    static func readCookie(_ token: String, now: Int = Int(Date().timeIntervalSince1970)) -> Int? {
        let pieces = token.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard pieces.count == 2 else { return nil }
        let payloadB64 = pieces[0]
        let signature = pieces[1]
        guard constantTimeEquals(Data(signature.utf8), Data(sign(payloadB64).utf8)) else { return nil }
        guard let data = b64Decode(payloadB64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let issuedAt = jsonInt(object["issued_at"]),
              let userId = jsonInt(object["user_id"]) else { return nil }
        if now - issuedAt > maxAge { return nil }
        return userId
    }

    private static func jsonInt(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private static func sign(_ payload: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return b64(Data(mac))
    }

    private static func pbkdf2(password: Data, salt: Data, iterations: Int, length: Int = 32) -> Data {
        precondition(iterations > 0)
        let blocks = Int((Double(length) / 32).rounded(.up))
        var derived = Data()
        for block in 1...blocks {
            var message = salt
            var index = UInt32(block).bigEndian
            withUnsafeBytes(of: &index) { message.append(contentsOf: $0) }
            var u = hmac(key: password, message: message)
            var blockBytes = [UInt8](u)
            if iterations > 1 {
                for _ in 2...iterations {
                    u = hmac(key: password, message: u)
                    let next = [UInt8](u)
                    for i in 0..<blockBytes.count { blockBytes[i] ^= next[i] }
                }
            }
            derived.append(contentsOf: blockBytes)
        }
        return derived.prefix(length)
    }

    private static func hmac(key: Data, message: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key)))
    }

    private static func b64(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func b64Decode(_ value: String) -> Data? {
        var text = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = (4 - (text.count % 4)) % 4
        text += String(repeating: "=", count: padding)
        return Data(base64Encoded: text)
    }

    private static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for pair in zip(lhs, rhs) { diff |= pair.0 ^ pair.1 }
        return diff == 0
    }
}
