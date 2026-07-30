import SwiftUI

/// Mirrors nocturne.css's `.seg`/`.seg-opt` segmented control, used for Dashboard's
/// All/Today/Due Soon scope switch and Curriculum's status filter.
public struct SegmentedScopeControl<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T

    public init(options: [(value: T, label: String)], selection: Binding<T>) {
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(selection == option.value ? DesignTokens.Colors.accent : DesignTokens.Colors.text)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .leading) {
                    if index > 0 {
                        Rectangle().fill(DesignTokens.Colors.divider).frame(width: 1)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(DesignTokens.Colors.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}
