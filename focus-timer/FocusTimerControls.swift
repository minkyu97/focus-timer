import SwiftUI

struct IconCircleButton: View {
    let systemName: String
    let accessibilityLabel: String
    var size: CGFloat = 38
    var foregroundColor: Color = .primary
    var backgroundColor: Color = Color.primary.opacity(0.07)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background(backgroundColor, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct OverlayHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            IconCircleButton(
                systemName: "chevron.left",
                accessibilityLabel: "Back",
                size: 34,
                action: onClose
            )

            Text(title)
                .font(.system(size: 15, weight: .semibold))

            Spacer()
        }
        .padding(.leading, 18)
        .padding(.trailing, 18)
        .padding(.top, MainWindowScene.headerTopPadding)
        .padding(.bottom, 8)
    }
}
