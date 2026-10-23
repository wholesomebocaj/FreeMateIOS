import SwiftUI

struct FilterOption: Identifiable, Hashable {
    var value: String
    var label: String
    var id: String { value }
}

/// The capsule every chip shares: filled with the accent when active, quiet otherwise.
struct FilterChipLabel: View {
    var text: String
    var systemImage: String?
    var isActive: Bool
    var showsChevron = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
            }
            Text(text)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .opacity(0.7)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .background(
            isActive ? AnyShapeStyle(DesignTokens.accent) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
            in: Capsule()
        )
        .contentShape(Capsule())
        .animation(DesignMotion.spring, value: isActive)
    }
}

/// A chip that opens a menu of choices. Shows its title until something other than `allValue`
/// is picked, then shows the pick.
struct FilterChipMenu: View {
    var title: String
    @Binding var selection: String
    var options: [FilterOption]
    var allValue = "all"

    var body: some View {
        let isActive = selection != allValue
        let current = options.first { $0.value == selection }?.label ?? title
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(option.label).tag(option.value)
                }
            }
        } label: {
            FilterChipLabel(text: isActive ? current : title, isActive: isActive, showsChevron: true)
        }
        .accessibilityLabel(title)
        .accessibilityValue(current)
    }
}

/// A chip that switches on with a tap, for small single-choice sets such as a side.
struct FilterChipToggle: View {
    var text: String
    var systemImage: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            FilterChipLabel(text: text, systemImage: systemImage, isActive: isSelected)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A clear-all chip that appears once any filter is active.
struct ClearFiltersChip: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                Text("Clear")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.secondary)
            .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("Clear filters")
        .transition(.scale.combined(with: .opacity))
    }
}

/// A horizontally scrolling row of chips that runs edge to edge.
struct FilterChipBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

/// A grouped-list style section title with an optional trailing accessory.
struct SectionHeader<Accessory: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            accessory()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}
