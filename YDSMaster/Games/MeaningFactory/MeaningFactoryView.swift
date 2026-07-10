import SwiftUI
import Combine

/// Conveyor-belt sorting game. A word crate rides the belt; the player drags
/// it into the machine with the matching meaning before it reaches the end.
struct MeaningFactoryView: View {
    @ObservedObject var session: GameSession
    var onRoundEnd: () -> Void

    // Belt state
    @State private var beltProgress: CGFloat = 0      // 0 → 1 across the screen
    @State private var isDragging = false
    @State private var dragTranslation: CGSize = .zero
    @State private var resolving = false
    @State private var crateVisible = true
    @State private var slowActive = false

    // Feedback
    @State private var reveal: (text: String, correct: Bool)?
    @State private var xpFloat: Int?
    @State private var machineFrames: [String: CGRect] = [:]
    @State private var rejectedMachine: String?
    @State private var acceptedMachine: String?
    @State private var escapeCount = 0
    @State private var showJamWarning = false

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var beltDuration: Double {
        let difficulty = Double(session.store.profile.startingDifficulty.rawValue)
        let base = 10.0 - difficulty - Double(session.index) * 0.25
        let clamped = max(5.5, base)
        return slowActive ? clamped * 1.8 : clamped
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ArenaBackground(mode: .meaningFactory)

                VStack(spacing: 0) {
                    GameHeaderView(
                        session: session,
                        accent: Theme.modeColor(.meaningFactory),
                        comboLabel: "SIRALAMA KOMBOSU"
                    ) {
                        onRoundEnd()
                    }
                    .padding(.top, 8)

                    if session.current?.variant == .partOfSpeech {
                        Text("KELİME TÜRÜNE GÖRE SIRALA")
                            .font(Theme.font(12, weight: .heavy))
                            .foregroundStyle(Color(hex: 0x0F1222))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.gold))
                            .padding(.top, 6)
                            .transition(.scale.combined(with: .opacity))
                    }

                    HStack {
                        if let reveal {
                            RevealTrayView(text: reveal.text, isCorrect: reveal.correct)
                        }
                        if let xpFloat {
                            FloatingXPView(amount: xpFloat).id(xpFloat)
                        }
                        if showJamWarning {
                            Label("Bant sıkışabilir!", systemImage: "exclamationmark.triangle.fill")
                                .font(Theme.font(13, weight: .bold))
                                .foregroundStyle(Theme.danger)
                                .transition(.opacity)
                        }
                    }
                    .frame(height: 54)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: reveal?.text)

                    // Conveyor belt + crate
                    beltArea(width: geo.size.width)
                        .frame(height: 150)
                        .padding(.top, 6)

                    Text(session.current?.variant == .partOfSpeech ? "Bu ne tür bir kelime?" : "Anlamına göre sırala")
                        .font(Theme.font(12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 14)

                    // Machines
                    machineGrid
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer()

                    HStack(spacing: 10) {
                        PowerUpButton(powerUp: .slowMotion, count: session.store.powerUpCount(.slowMotion)) {
                            if session.useSlowMotion() {
                                Haptics.selection()
                                slowActive = true
                            }
                        }
                        PowerUpButton(powerUp: .removeWrong, count: session.store.powerUpCount(.removeWrong)) {
                            if let removed = session.useRemoveWrong() {
                                Haptics.selection()
                                removedOptions.insert(removed)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .coordinateSpace(name: "factory")
            .onReceive(timer) { _ in
                tickBelt()
            }
            .onPreferenceChange(MachineFramePreferenceKey.self) { frames in
                machineFrames = frames
            }
        }
    }

    @State private var removedOptions: Set<String> = []

    // MARK: Belt

    private func beltArea(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            // Belt track
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x11152A))
                        .frame(height: 34)
                    // Moving stripes
                    HStack(spacing: 26) {
                        ForEach(0..<12, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.10))
                                .frame(width: 8, height: 34)
                                .rotationEffect(.degrees(20))
                        }
                    }
                    .offset(x: beltProgress.truncatingRemainder(dividingBy: 0.12) * width * 2)
                    .clipped()
                    // Rollers under the belt (must stay narrower than any iPhone screen)
                    HStack(spacing: 28) {
                        ForEach(0..<7, id: \.self) { _ in
                            Circle()
                                .fill(Color(hex: 0x2A3150))
                                .overlay(Circle().fill(Color.black.opacity(0.5)).frame(width: 5, height: 5))
                                .frame(width: 14, height: 14)
                        }
                    }
                    .offset(y: 24)
                }
            }
            .frame(height: 60)
            .offset(y: 40)

            // Crate
            if crateVisible, let question = session.current {
                crateView(question: question)
                    .position(cratePosition(width: width))
                    .gesture(crateDragGesture(width: width))
                    .animation(isDragging ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: dragTranslation)
            }
        }
    }

    private func crateView(question: Question) -> some View {
        Group {
            if let art = GameAssets.image("crate") {
                // Crate art at its natural aspect ratio, with the word on a
                // stamped label plaque overlaid on its front face (not raw
                // text floating on the artwork).
                art
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 108)
                    .overlay(alignment: .center) {
                        wordPlaque(question.prompt)
                            .offset(y: 4)
                    }
            } else {
                VStack(spacing: 2) {
                    Text("📦").font(.system(size: 20))
                    Text(question.prompt)
                        .font(Theme.font(question.prompt.count > 12 ? 13 : 16, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: 110)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0xB98A44), Color(hex: 0x8A6533)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
                )
            }
        }
        .scaleEffect(isDragging ? 1.12 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isDragging)
    }

    /// A small stamped-label plaque for a word — used on top of art (crate,
    /// machines) so text reads as a designed label rather than pasted text.
    private func wordPlaque(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(16, weight: .heavy))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.55)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: 86)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
    }

    private func cratePosition(width: CGFloat) -> CGPoint {
        let baseX = -70 + beltProgress * (width + 100)
        let baseY: CGFloat = 62
        return CGPoint(x: baseX + dragTranslation.width, y: baseY + dragTranslation.height)
    }

    private func crateDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(coordinateSpace: .named("factory"))
            .onChanged { value in
                guard !resolving else { return }
                if !isDragging {
                    isDragging = true
                    Haptics.light()
                }
                dragTranslation = value.translation
            }
            .onEnded { value in
                guard !resolving else { return }
                isDragging = false
                let dropPoint = value.location
                if let (option, _) = machineFrames.first(where: { $0.value.contains(dropPoint) }) {
                    resolveDrop(into: option)
                } else {
                    // Snap back to the belt
                    dragTranslation = .zero
                }
            }
    }

    private func tickBelt() {
        guard !isDragging, !resolving, crateVisible, session.current != nil else { return }
        beltProgress += CGFloat(1.0 / (30.0 * beltDuration))
        if beltProgress >= 1 {
            // Word escaped — requeue it, warn about jams.
            escapeCount += 1
            Haptics.warning()
            if escapeCount >= 2 {
                withAnimation { showJamWarning = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { showJamWarning = false }
                }
            }
            session.requeueCurrent()
            if session.isFinished {
                onRoundEnd()
            } else {
                prepareNextWord()
            }
        }
    }

    // MARK: Machines

    private var machineOptions: [String] {
        guard let question = session.current else { return [] }
        return question.options.filter { !removedOptions.contains($0) }
    }

    private var machineGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            ForEach(machineOptions, id: \.self) { option in
                machineView(option)
            }
        }
    }

    /// Part-of-speech bins get their own colors (mockup style).
    private func machineTint(_ option: String) -> Color {
        guard session.current?.variant == .partOfSpeech else {
            return Theme.modeColor(.meaningFactory)
        }
        switch option {
        case PartOfSpeech.verb.turkishName: return Theme.accent
        case PartOfSpeech.noun.turkishName: return Theme.gold
        case PartOfSpeech.adjective.turkishName: return Theme.orange
        default: return Theme.purple
        }
    }

    private func machineView(_ option: String) -> some View {
        let isRejected = rejectedMachine == option
        let isAccepted = acceptedMachine == option
        return VStack(spacing: 6) {
            // Hopper mouth
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.55))
                .frame(width: 64, height: 12)
            Text(option)
                .font(Theme.font(option.count > 12 ? 14 : 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 44)
            if isAccepted {
                Text("💨").transition(.scale)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isAccepted ? Theme.success.opacity(0.25) : isRejected ? Theme.danger.opacity(0.25) : Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isAccepted ? Theme.success : isRejected ? Theme.danger : machineTint(option).opacity(0.5),
                            lineWidth: 2
                        )
                )
        )
        .overlay(alignment: .topTrailing) {
            // Status light
            Circle()
                .fill(isAccepted ? Theme.success : isRejected ? Theme.danger : machineTint(option).opacity(0.7))
                .frame(width: 9, height: 9)
                .shadow(color: isAccepted ? Theme.success : isRejected ? Theme.danger : .clear, radius: 5)
                .padding(10)
        }
        .overlay(alignment: .bottom) {
            // Bolts
            HStack {
                Circle().fill(Color.black.opacity(0.45)).frame(width: 7, height: 7)
                Spacer()
                Circle().fill(Color.black.opacity(0.45)).frame(width: 7, height: 7)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .scaleEffect(isAccepted ? 1.06 : 1)
        .offset(x: isRejected ? -6 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: isRejected)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isAccepted)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MachineFramePreferenceKey.self,
                    value: [option: geo.frame(in: .named("factory"))]
                )
            }
        )
    }

    // MARK: Resolution

    private func resolveDrop(into option: String) {
        guard session.current != nil else { return }
        resolving = true
        let feedback = session.submit(answer: option)

        switch feedback {
        case .correct(let gained, let revealText, _):
            SoundManager.shared.play(.stamp)
            Haptics.success()
            acceptedMachine = option
            reveal = (revealText, true)
            xpFloat = gained
            withAnimation(.easeIn(duration: 0.18)) { crateVisible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                acceptedMachine = nil
                if session.advance() {
                    prepareNextWord()
                } else {
                    onRoundEnd()
                }
            }

        case .wrong(_, let shieldUsed):
            // No reveal — the player retries this crate.
            SoundManager.shared.play(.reject)
            Haptics.error()
            rejectedMachine = option
            if !shieldUsed, session.loseLife() <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onRoundEnd() }
                return
            }
            // Machine spits the crate back onto the belt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                rejectedMachine = nil
                dragTranslation = .zero
                beltProgress = min(beltProgress, 0.15) // crate pops back near the start
                resolving = false
            }
        }
    }

    private func prepareNextWord() {
        removedOptions = []
        slowActive = false
        beltProgress = 0
        dragTranslation = .zero
        session.markQuestionShown()
        crateVisible = true
        resolving = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {}
    }
}

// MARK: - Machine frame collection

private struct MachineFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
