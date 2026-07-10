import SwiftUI

/// Per-mode arena backdrop: keeps the premium dark base but gives each game
/// its own colorful atmosphere (sky, starfield, factory floor, ember canyon).
struct ArenaBackground: View {
    let mode: GameMode
    @State private var animate = false

    var body: some View {
        ZStack {
            if let art = GameAssets.image("arena_\(mode.rawValue)") {
                // User-provided arena art, dimmed slightly so HUD text stays readable.
                GeometryReader { geo in
                    art
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                LinearGradient(
                    colors: [.black.opacity(0.35), .black.opacity(0.15), .black.opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                baseGradient.ignoresSafeArea()
                decorations
            }
        }
        .onAppear { animate = true }
    }

    private var baseGradient: LinearGradient {
        switch mode {
        case .wordCannon:
            return LinearGradient(
                colors: [Color(hex: 0x0B1B33), Color(hex: 0x0E2E40), Color(hex: 0x123A33)],
                startPoint: .top, endPoint: .bottom)
        case .wordSlice:
            return LinearGradient(
                colors: [Color(hex: 0x140F33), Color(hex: 0x1F1147), Color(hex: 0x2A0F3E)],
                startPoint: .top, endPoint: .bottom)
        case .meaningFactory:
            return LinearGradient(
                colors: [Color(hex: 0x0A1F22), Color(hex: 0x0E2B2A), Color(hex: 0x123230)],
                startPoint: .top, endPoint: .bottom)
        case .monsterBattle:
            return LinearGradient(
                colors: [Color(hex: 0x220E14), Color(hex: 0x2E1512), Color(hex: 0x1A0B18)],
                startPoint: .top, endPoint: .bottom)
        case .wordHuntMirror:
            return LinearGradient(
                colors: [Color(hex: 0x0C1F1D), Color(hex: 0x11302B), Color(hex: 0x0A211F)],
                startPoint: .top, endPoint: .bottom)
        case .wordInvaders:
            return LinearGradient(
                colors: [Color(hex: 0x05060F), Color(hex: 0x0C0F24), Color(hex: 0x040509)],
                startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder
    private var decorations: some View {
        GeometryReader { geo in
            switch mode {
            case .wordCannon:
                // Distant hills and drifting clouds
                ZStack {
                    Ellipse()
                        .fill(Color(hex: 0x1B4D3E).opacity(0.5))
                        .frame(width: geo.size.width * 1.6, height: 260)
                        .offset(x: -geo.size.width * 0.3, y: geo.size.height - 130)
                    Ellipse()
                        .fill(Color(hex: 0x175243).opacity(0.4))
                        .frame(width: geo.size.width * 1.4, height: 220)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height - 100)
                    ForEach(0..<3, id: \.self) { i in
                        Ellipse()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 150 + CGFloat(i) * 40, height: 36)
                            .offset(
                                x: CGFloat(i) * geo.size.width * 0.33 + (animate ? 18 : -18),
                                y: geo.size.height * 0.16 + CGFloat(i) * 54
                            )
                            .animation(
                                .easeInOut(duration: 7 + Double(i) * 2).repeatForever(autoreverses: true),
                                value: animate
                            )
                    }
                }
            case .wordSlice:
                // Starfield + nebula glows
                ZStack {
                    ForEach(0..<26, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(Double((i * 7) % 5) * 0.05 + 0.08))
                            .frame(width: CGFloat((i * 13) % 3) + 1.5)
                            .position(
                                x: CGFloat((i * 137) % Int(max(geo.size.width, 1))),
                                y: CGFloat((i * 211) % Int(max(geo.size.height, 1)))
                            )
                    }
                    Circle()
                        .fill(RadialGradient(colors: [Theme.purple.opacity(0.22), .clear],
                                             center: .center, startRadius: 5, endRadius: 190))
                        .frame(width: 380)
                        .position(x: geo.size.width * 0.82, y: geo.size.height * 0.24)
                    Circle()
                        .fill(RadialGradient(colors: [Theme.accent.opacity(0.14), .clear],
                                             center: .center, startRadius: 5, endRadius: 160))
                        .frame(width: 320)
                        .position(x: geo.size.width * 0.12, y: geo.size.height * 0.7)
                }
            case .meaningFactory:
                // Slowly turning gears
                ZStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 190))
                        .foregroundStyle(Color.white.opacity(0.05))
                        .rotationEffect(.degrees(animate ? 360 : 0))
                        .animation(.linear(duration: 34).repeatForever(autoreverses: false), value: animate)
                        .position(x: geo.size.width * 0.88, y: geo.size.height * 0.22)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(Color.white.opacity(0.06))
                        .rotationEffect(.degrees(animate ? -360 : 0))
                        .animation(.linear(duration: 26).repeatForever(autoreverses: false), value: animate)
                        .position(x: geo.size.width * 0.08, y: geo.size.height * 0.34)
                    // Pipes
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 18, height: geo.size.height * 0.5)
                        .position(x: geo.size.width * 0.05, y: geo.size.height * 0.68)
                }
            case .monsterBattle:
                // Canyon arches + rising embers
                ZStack {
                    ForEach(0..<2, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 60)
                            .stroke(Color(hex: 0x5A2E1E).opacity(0.5), lineWidth: 26)
                            .frame(width: 180, height: 320)
                            .position(
                                x: i == 0 ? geo.size.width * 0.1 : geo.size.width * 0.92,
                                y: geo.size.height * 0.42
                            )
                    }
                    ForEach(0..<10, id: \.self) { i in
                        Circle()
                            .fill(Theme.orange.opacity(0.35))
                            .frame(width: CGFloat((i * 11) % 4) + 2)
                            .position(
                                x: CGFloat((i * 97) % Int(max(geo.size.width, 1))),
                                y: geo.size.height * (animate ? 0.1 : 0.95)
                            )
                            .animation(
                                .linear(duration: 7 + Double(i)).repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.7),
                                value: animate
                            )
                    }
                }
            case .wordHuntMirror:
                // Floating faded letters, like a library/word-search backdrop
                ZStack {
                    ForEach(Array("ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ".enumerated()), id: \.offset) { i, letter in
                        Text(String(letter))
                            .font(.system(size: 22 + CGFloat(i % 3) * 6, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.teal.opacity(0.06))
                            .position(
                                x: CGFloat((i * 173) % Int(max(geo.size.width, 1))),
                                y: CGFloat((i * 251) % Int(max(geo.size.height, 1)))
                            )
                            .rotationEffect(.degrees(animate ? Double(i % 2 == 0 ? 8 : -8) : 0))
                            .animation(
                                .easeInOut(duration: 5 + Double(i % 4)).repeatForever(autoreverses: true),
                                value: animate
                            )
                    }
                }
            case .wordInvaders:
                // Circuit-board grid for Word Circuit.
                ZStack {
                    ForEach(0..<9, id: \.self) { i in
                        Rectangle()
                            .fill(Theme.indigo.opacity(0.07))
                            .frame(width: 1.2, height: geo.size.height)
                            .position(x: geo.size.width * CGFloat(i + 1) / 10, y: geo.size.height / 2)
                    }
                    ForEach(0..<14, id: \.self) { i in
                        Rectangle()
                            .fill(Theme.success.opacity(0.05))
                            .frame(width: geo.size.width, height: 1)
                            .position(x: geo.size.width / 2, y: geo.size.height * CGFloat(i + 1) / 15)
                    }
                    ForEach(0..<7, id: \.self) { i in
                        Path { path in
                            let startX = geo.size.width * CGFloat((i * 17) % 9 + 1) / 10
                            let startY = geo.size.height * CGFloat(i + 2) / 10
                            path.move(to: CGPoint(x: startX, y: startY))
                            path.addLine(to: CGPoint(x: startX + geo.size.width * 0.18, y: startY))
                            path.addLine(to: CGPoint(x: startX + geo.size.width * 0.18, y: startY + geo.size.height * 0.08))
                            path.addLine(to: CGPoint(x: startX + geo.size.width * 0.33, y: startY + geo.size.height * 0.08))
                        }
                        .stroke(i % 2 == 0 ? Theme.success.opacity(0.14) : Theme.gold.opacity(0.12),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .offset(x: animate ? 8 : -8)
                        .animation(
                            .easeInOut(duration: 4 + Double(i % 3)).repeatForever(autoreverses: true),
                            value: animate
                        )
                    }
                    Image(systemName: "memorychip.fill")
                        .font(.system(size: 150, weight: .bold))
                        .foregroundStyle(Theme.indigo.opacity(0.08))
                        .rotationEffect(.degrees(animate ? 2 : -2))
                        .position(x: geo.size.width * 0.82, y: geo.size.height * 0.22)
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill((i % 2 == 0 ? Theme.gold : Theme.success).opacity(0.22))
                            .frame(width: 5, height: 5)
                            .position(
                                x: geo.size.width * CGFloat((i * 19) % 10 + 1) / 11,
                                y: geo.size.height * CGFloat((i * 23) % 12 + 1) / 13
                            )
                            .animation(
                                .easeInOut(duration: 2.5 + Double(i % 4)).repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.4),
                                value: animate
                            )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
