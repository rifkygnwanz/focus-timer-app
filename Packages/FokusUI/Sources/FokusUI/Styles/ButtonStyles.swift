import SwiftUI

// MARK: - PrimaryButtonStyle

public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity)
            .background(Palette.accent, in: Capsule())
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

// MARK: - SecondaryButtonStyle

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.lg)
            .background(Palette.secondaryBackground, in: Capsule())
            .foregroundStyle(Palette.label)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

// MARK: - IconButtonStyle

public struct IconButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .medium))
            .frame(width: 48, height: 48)
            .background(Palette.secondaryBackground, in: Circle())
            .foregroundStyle(Palette.secondaryLabel)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Button Styles") {
    VStack(spacing: Spacing.lg) {
        Button("Mulai") {}
            .buttonStyle(PrimaryButtonStyle())

        Button("Berhenti") {}
            .buttonStyle(SecondaryButtonStyle())

        Button { } label: {
            Image(systemName: "forward.fill")
        }
        .buttonStyle(IconButtonStyle())
    }
    .padding(Spacing.lg)
}
