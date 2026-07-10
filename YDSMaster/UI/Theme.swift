import SwiftUI

/// YDS Master design language: premium dark arcade, not childish.
enum Theme {
    // MARK: Palette

    static let bgTop = Color(hex: 0x0F1222)
    static let bgBottom = Color(hex: 0x1B1035)
    static let card = Color(hex: 0x1C2138)
    static let cardBorder = Color.white.opacity(0.08)

    static let accent = Color(hex: 0x22D3EE)      // cyan
    static let purple = Color(hex: 0x8B5CF6)
    static let gold = Color(hex: 0xFBBF24)
    static let success = Color(hex: 0x34D399)
    static let danger = Color(hex: 0xF87171)
    static let orange = Color(hex: 0xFB923C)
    static let teal = Color(hex: 0x2DD4BF)
    static let magenta = Color(hex: 0xEC4899)
    static let indigo = Color(hex: 0x818CF8)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)

    static var background: some View {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    static func modeColor(_ mode: GameMode) -> Color {
        switch mode {
        case .wordCannon: return accent
        case .wordSlice: return orange
        case .meaningFactory: return success
        case .monsterBattle: return purple
        case .wordHuntMirror: return teal
        case .wordInvaders: return indigo
        }
    }

    // MARK: Typography (rounded = friendly but adult)

    static func font(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Brightness-scaled variant (for 3D button lips and gradient tops).
    func adjusted(brightness factor: CGFloat) -> Color {
        #if canImport(UIKit)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return Color(hue: h, saturation: s, brightness: min(1, b * factor), opacity: a)
        }
        #endif
        return self
    }
}

// MARK: - Game-title typography (gold gradient, mockup style)

struct GameTitleText: View {
    let text: String
    var size: CGFloat = 34

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: 0xFFE985), Theme.gold, Theme.orange],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .shadow(color: .black.opacity(0.85), radius: 0, y: 3)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 5)
    }
}

// MARK: - Buttons

/// Chunky mobile-game button: gradient face over a darker bottom "lip";
/// pressing pushes the face down into the lip. Every layer is sized by the
/// label — no free-floating shapes that can grow past the button.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    private let lip: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(18, weight: .heavy))
            .foregroundStyle(Color(hex: 0x0F1222))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.adjusted(brightness: 1.25), color],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    )
            )
            .offset(y: configuration.isPressed ? lip - 1 : 0)
            .padding(.bottom, lip)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color.adjusted(brightness: 0.55))
            )
            .shadow(color: color.opacity(0.35), radius: configuration.isPressed ? 3 : 9, y: 5)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(16, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.cardBorder))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Card container

struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Theme.cardBorder)
                    )
            )
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 20) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }

    /// Beveled arcade panel: dark fill, light-catching top edge, drop shadow.
    func arcadePanel(cornerRadius: CGFloat = 16, tint: Color = .white) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [tint.opacity(0.45), tint.opacity(0.08)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.45), radius: 5, y: 4)
        )
    }
}
