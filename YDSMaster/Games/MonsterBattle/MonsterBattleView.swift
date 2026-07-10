import SwiftUI

/// Battle mode: each question is a monster with a meaning on its chest.
/// Flick the correct word weapon at it. The last three questions form a
/// 3-hit BOSS golem built from previously missed / confusing words.
struct MonsterBattleView: View {
    @ObservedObject var session: GameSession
    var onRoundEnd: () -> Void

    // Battle state
    @State private var monsterHP: CGFloat = 1.0
    @State private var monsterHurt = false
    @State private var monsterAttacking = false
    @State private var monsterDefeated = false
    @State private var attackFlash = false

    // Throw state
    @State private var draggedOption: String?
    @State private var dragOffset: CGSize = .zero
    @State private var projectile: (word: String, flying: Bool)?
    @State private var resolving = false

    // Feedback
    @State private var reveal: (text: String, correct: Bool)?
    @State private var xpFloat: Int?
    @State private var damageNumber: (amount: Int, critical: Bool)?
    @State private var hintLetter: String?
    @State private var removedOptions: Set<String> = []

    private let monsterEmojis = ["👾", "🧌", "👹", "🤖", "👻", "🦂", "🧟", "🐙", "🦇"]

    // MARK: Boss bookkeeping

    /// The last (up to) 3 questions belong to the boss.
    private var bossStartIndex: Int { max(1, session.totalQuestions - 3) }
    private var isBossQuestion: Bool { session.index >= bossStartIndex }
    private var bossTotalHits: Int { max(1, session.totalQuestions - bossStartIndex) }

    private var monsterName: String {
        if isBossQuestion { return "BOSS — Kelime Golemi" }
        guard let question = session.current else { return "Canavar" }
        if question.word.confusingWords.count >= 2 { return "Karışan Kelimeler Canavarı" }
        switch question.word.partOfSpeech {
        case .verb: return "Fiil Canavarı"
        case .adjective: return "Sıfat Canavarı"
        case .noun: return "İsim Canavarı"
        default: return "Kelime Canavarı"
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ArenaBackground(mode: .monsterBattle)

                // Monster attack flash
                Rectangle()
                    .fill(Theme.danger.opacity(attackFlash ? 0.25 : 0))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    GameHeaderView(session: session, accent: Theme.modeColor(.monsterBattle)) {
                        onRoundEnd()
                    }
                    .padding(.top, 8)

                    // Monster vs player HP bars (mockup style, with %)
                    hpBars
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    HStack {
                        Spacer()
                        if let reveal {
                            RevealTrayView(text: reveal.text, isCorrect: reveal.correct)
                        }
                        if let xpFloat {
                            FloatingXPView(amount: xpFloat).id(xpFloat)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: reveal?.text)

                    Spacer(minLength: 0)

                    // Monster
                    monsterView

                    if let hintLetter {
                        Text("Şununla başlıyor: “\(hintLetter)”")
                            .font(Theme.font(14, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 0)

                    // Weapon words
                    weaponGrid
                        .padding(.horizontal, 16)

                    // Power-ups + progression tray
                    HStack(alignment: .bottom, spacing: 10) {
                        PowerUpButton(powerUp: .firstLetter, count: session.store.powerUpCount(.firstLetter)) {
                            if let letter = session.useFirstLetter() {
                                Haptics.selection()
                                hintLetter = letter
                            }
                        }
                        PowerUpButton(powerUp: .removeWrong, count: session.store.powerUpCount(.removeWrong)) {
                            if let removed = session.useRemoveWrong() {
                                Haptics.selection()
                                removedOptions.insert(removed)
                            }
                        }
                        PowerUpButton(powerUp: .shield, count: session.store.powerUpCount(.shield)) {
                            if session.useShield() { Haptics.selection() }
                        }
                        Spacer()
                        progressionTray
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                // Flying projectile
                if let projectile {
                    weaponCapsule(projectile.word, compact: true)
                        .position(
                            x: geo.size.width / 2,
                            y: projectile.flying ? geo.size.height * 0.34 : geo.size.height * 0.72
                        )
                        .scaleEffect(projectile.flying ? 0.55 : 1)
                        .opacity(projectile.flying ? 0.9 : 1)
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear { session.markQuestionShown() }
    }

    // MARK: HP bars

    /// How many of the boss's required hits have already landed.
    private var bossHitsDone: Int { max(0, min(bossTotalHits, session.index - bossStartIndex)) }

    private var hpBars: some View {
        HStack(spacing: 14) {
            // Monster side
            HStack(spacing: 6) {
                Text(isBossQuestion ? "🗿" : "👾").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    hpBar(fraction: monsterHP, color: Theme.danger)
                    // Regular monsters die in one hit, so their % is almost
                    // always 100 and reads as "nothing happened" — show only
                    // the round-wide kill count instead. The boss actually
                    // takes several hits, so its % is meaningful and paired
                    // with a hit counter.
                    if isBossQuestion {
                        HStack(spacing: 6) {
                            Text("\(Int(max(0, monsterHP) * 100))%")
                            Text("· Vuruş: \(bossHitsDone)/\(bossTotalHits)")
                        }
                        .font(Theme.font(10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Canavar: \(min(session.index + 1, session.totalQuestions))/\(session.totalQuestions)")
                            .font(Theme.font(10, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            Spacer()
            // Player side
            HStack(spacing: 6) {
                VStack(alignment: .trailing, spacing: 2) {
                    hpBar(fraction: CGFloat(session.lives) / 3, color: Theme.success)
                    Text("\(Int(Double(session.lives) / 3 * 100))%")
                        .font(Theme.font(10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                if let wizard = GameAssets.image("wizard") {
                    wizard.resizable().scaledToFit().frame(width: 32, height: 32)
                } else {
                    Text("🧙").font(.system(size: 20))
                }
            }
        }
    }

    private func hpBar(fraction: CGFloat, color: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12))
            Capsule()
                .fill(color)
                .frame(width: max(0, 110 * min(1, fraction)))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: fraction)
        }
        .frame(width: 110, height: 8)
    }

    // MARK: Monster (word golem)

    private var monsterView: some View {
        VStack(spacing: 8) {
            Text(monsterName.turkishUppercased)
                .font(Theme.font(13, weight: .heavy))
                .foregroundStyle(isBossQuestion ? Theme.danger : Theme.textSecondary)

            ZStack {
                // Aura
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [(isBossQuestion ? Theme.danger : Theme.purple).opacity(0.3), .clear],
                            center: .center, startRadius: 10, endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)

                golemBody
                    .scaleEffect(monsterDefeated ? 0.1 : monsterHurt ? 0.92 : monsterAttacking ? 1.18 : 1)
                    .rotationEffect(.degrees(monsterDefeated ? 30 : 0))
                    .opacity(monsterDefeated ? 0 : 1)
                    .offset(y: monsterAttacking ? 34 : 0)

                // Damage number
                if let damage = damageNumber {
                    Text(damage.critical ? "-\(damage.amount) CRIT!" : "-\(damage.amount)")
                        .font(Theme.font(damage.critical ? 30 : 24, weight: .heavy))
                        .foregroundStyle(damage.critical ? Theme.gold : Theme.orange)
                        .offset(x: 70, y: -70)
                        .transition(.asymmetric(
                            insertion: .offset(y: 20).combined(with: .opacity),
                            removal: .offset(y: -30).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: monsterHurt)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: monsterAttacking)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: monsterDefeated)
        }
    }

    /// Uses `golem` / `golem_boss` art when provided; otherwise the code-drawn golem.
    private var golemBody: some View {
        Group {
            if let art = GameAssets.image(isBossQuestion ? "golem_boss" : "golem") {
                art
                    .resizable()
                    .scaledToFit()
                    .frame(height: 240 * (isBossQuestion ? 1.2 : 1.0))
                    .overlay(alignment: .center) {
                        chestWord(scale: isBossQuestion ? 1.2 : 1.0)
                            .offset(y: 26)
                    }
            } else {
                vectorGolem
            }
        }
    }

    /// The prompt plate rendered on the monster's chest.
    @ViewBuilder
    private func chestWord(scale: CGFloat) -> some View {
        if let question = session.current, !monsterDefeated {
            Text(question.prompt)
                .font(Theme.font(20, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke((isBossQuestion ? Theme.danger : Theme.purple).opacity(0.8), lineWidth: 2)
                        )
                )
                .frame(maxWidth: 150 * scale)
        }
    }

    /// Stone golem built from shapes, its body "carved" with faded words —
    /// the current prompt sits on its chest.
    private var vectorGolem: some View {
        let stone = LinearGradient(
            colors: isBossQuestion
                ? [Color(hex: 0x6B4A38), Color(hex: 0x4A3227)]
                : [Color(hex: 0x55606E), Color(hex: 0x39414D)],
            startPoint: .top, endPoint: .bottom
        )
        let scale: CGFloat = isBossQuestion ? 1.2 : 1.0

        return ZStack {
            // Arms
            HStack(spacing: 128 * scale) {
                RoundedRectangle(cornerRadius: 16).fill(stone).frame(width: 30 * scale, height: 96 * scale)
                RoundedRectangle(cornerRadius: 16).fill(stone).frame(width: 30 * scale, height: 96 * scale)
            }
            .offset(y: 6)
            .rotationEffect(.degrees(monsterAttacking ? 6 : 0))

            // Torso
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(stone)
                .frame(width: 140 * scale, height: 150 * scale)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.black.opacity(0.35), lineWidth: 3)
                )
                .overlay(wordCarvings.clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous)))

            // Head with glowing eyes
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(stone)
                    .frame(width: 66 * scale, height: 46 * scale)
                    .overlay(
                        HStack(spacing: 14) {
                            Circle().fill(isBossQuestion ? Theme.danger : Theme.accent).frame(width: 8, height: 8)
                            Circle().fill(isBossQuestion ? Theme.danger : Theme.accent).frame(width: 8, height: 8)
                        }
                    )
                Spacer()
            }
            .frame(height: 220 * scale)

            // Chest word (the prompt)
            chestWord(scale: scale)
                .offset(y: 14)
        }
        .frame(height: 230 * scale)
    }

    /// Faded words "carved" into the golem's body.
    private var wordCarvings: some View {
        let carved = session.questions.prefix(6).map(\.word.englishWord)
        return VStack(spacing: 6) {
            ForEach(Array(carved.enumerated()), id: \.offset) { i, word in
                Text(word.uppercased())
                    .font(Theme.font(11, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.22))
                    .rotationEffect(.degrees(i.isMultiple(of: 2) ? -4 : 3))
            }
        }
    }

    // MARK: Progression / review tray

    private var progressionTray: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("İLERLEME")
                .font(Theme.font(9, weight: .heavy))
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
            ForEach(session.revealHistory.suffix(3), id: \.self) { entry in
                Text(entry)
                    .font(Theme.font(11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 190, alignment: .trailing)
    }

    // MARK: Weapons

    private var weaponOptions: [String] {
        guard let question = session.current else { return [] }
        return question.options.filter { !removedOptions.contains($0) }
    }

    private var weaponGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            ForEach(weaponOptions, id: \.self) { option in
                weaponCapsule(option, compact: false)
                    .offset(draggedOption == option ? dragOffset : .zero)
                    .opacity(projectile?.word == option ? 0 : 1)
                    .gesture(throwGesture(option))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragOffset)
            }
        }
    }

    private func weaponCapsule(_ word: String, compact: Bool) -> some View {
        Text(word)
            .font(Theme.font(word.count > 12 ? 14 : 17, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: compact ? 160 : .infinity, minHeight: compact ? 40 : 56)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.modeColor(.monsterBattle).opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: Theme.modeColor(.monsterBattle).opacity(0.25), radius: 6, y: 3)
            )
    }

    private func throwGesture(_ option: String) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !resolving else { return }
                if draggedOption == nil { Haptics.light() }
                draggedOption = option
                dragOffset = value.translation
            }
            .onEnded { value in
                defer { draggedOption = nil; dragOffset = .zero }
                guard !resolving else { return }
                if value.translation.height < -70 || value.predictedEndTranslation.height < -180 {
                    throwWord(option)
                }
            }
    }

    // MARK: Battle resolution

    private func throwWord(_ word: String) {
        resolving = true
        hintLetter = nil
        projectile = (word, false)
        Haptics.medium()

        withAnimation(.easeIn(duration: 0.28)) {
            projectile = (word, true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            resolveThrow(word)
        }
    }

    private func resolveThrow(_ word: String) {
        let feedback = session.submit(answer: word)
        projectile = nil

        switch feedback {
        case .correct(let gained, let revealText, let critical):
            SoundManager.shared.play(.monsterHit)
            Haptics.success()
            reveal = (revealText, true)
            xpFloat = gained
            withAnimation { damageNumber = (critical ? 150 : 100, critical) }
            monsterHurt = true

            if isBossQuestion {
                // Boss soaks several hits before falling.
                let hitsDone = session.index - bossStartIndex + 1
                monsterHP = 1 - CGFloat(hitsDone) / CGFloat(bossTotalHits)
            } else {
                monsterHP = 0
            }

            let dies = monsterHP <= 0.01
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                monsterHurt = false
                if dies {
                    monsterDefeated = true
                    SoundManager.shared.play(isBossQuestion ? .bossDefeat : .pop)
                    if isBossQuestion {
                        Haptics.heavy()
                        session.store.earnBadge("boss-slayer")
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { damageNumber = nil }
                nextMonster(bossContinues: isBossQuestion && !dies)
            }

        case .wrong(let revealText, let shieldUsed):
            // Monster eats the word and strikes back; the pair is revealed
            // briefly so the player still learns, then we move on.
            SoundManager.shared.play(.monsterRoar)
            Haptics.error()
            reveal = (revealText, false)
            monsterAttacking = true
            withAnimation(.easeOut(duration: 0.12)) { attackFlash = true }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                monsterAttacking = false
                withAnimation(.easeIn(duration: 0.3)) { attackFlash = false }
                var remaining = session.lives
                if !shieldUsed {
                    remaining = session.loseLife()
                }
                if remaining <= 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onRoundEnd() }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        nextMonster(bossContinues: isBossQuestion)
                    }
                }
            }
        }
    }

    private func nextMonster(bossContinues: Bool) {
        if session.advance() {
            if !bossContinues {
                monsterHP = 1.0
                monsterDefeated = false
            }
            removedOptions = []
            resolving = false
            session.markQuestionShown()
        } else {
            onRoundEnd()
        }
    }
}
