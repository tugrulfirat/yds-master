import Foundation

/// A meaning family for Word Circuit: one Turkish target meaning, the
/// English words that belong to it (correct path tiles), and confusing
/// English words that do NOT belong to it (decoy tiles).
///
/// This is intentionally a separate, lightweight data model from `Word` —
/// bolting synonym-family metadata onto the shared 5000-word `Word` schema
/// would force every other game mode's dataset to carry fields they don't
/// need. When a cluster word also exists in the main word bank, mastery
/// still updates for real (see `WordInvadersSession`); when it doesn't
/// (yet — the sample bank is only 46 words), the round still teaches the
/// pairing visually, it just can't move that word's mastery score.
struct SynonymCluster: Identifiable {
    let id: String
    let meaningFamilyTR: String
    /// English word → its own accurate Turkish gloss (for reveals/corrections).
    let correctWords: [(en: String, tr: String)]
    let wrongWords: [(en: String, tr: String)]
    let nuanceNoteTR: String
    var isBoss: Bool = false

    var allWords: [(en: String, tr: String)] { correctWords + wrongWords }

    func turkishGloss(for englishWord: String) -> String {
        allWords.first { $0.en.caseInsensitiveCompare(englishWord) == .orderedSame }?.tr ?? ""
    }

    func isCorrect(_ englishWord: String) -> Bool {
        correctWords.contains { $0.en.caseInsensitiveCompare(englishWord) == .orderedSame }
    }

    static let all: [SynonymCluster] = [
        SynonymCluster(
            id: "azaltmak",
            meaningFamilyTR: "azaltmak / azalmak",
            correctWords: [("reduce", "azaltmak"), ("decrease", "azaltmak"), ("diminish", "azaltmak"), ("decline", "azalmak")],
            wrongWords: [("increase", "artırmak"), ("expand", "genişletmek"), ("improve", "geliştirmek"), ("produce", "üretmek")],
            nuanceNoteTR: "Bu kelimelerin hepsi bir şeyi küçültme/azaltma fikrini taşır ama \"decline\" genelde kendiliğinden azalmayı, diğerleri ise bir etkenin azaltmasını anlatır."
        ),
        SynonymCluster(
            id: "artirmak",
            meaningFamilyTR: "artırmak / büyütmek",
            correctWords: [("increase", "artırmak"), ("raise", "yükseltmek"), ("expand", "genişletmek"), ("enhance", "geliştirmek")],
            wrongWords: [("reduce", "azaltmak"), ("decline", "azalmak"), ("avoid", "kaçınmak"), ("prevent", "önlemek")],
            nuanceNoteTR: "\"Raise\" genelde somut bir şeyi (fiyat, ses) yükseltirken, \"enhance\" bir şeyin kalitesini artırmak için kullanılır."
        ),
        SynonymCluster(
            id: "onlemek",
            meaningFamilyTR: "önlemek / engellemek",
            correctWords: [("prevent", "önlemek"), ("avoid", "kaçınmak"), ("hinder", "engellemek"), ("prohibit", "yasaklamak"), ("block", "engellemek")],
            wrongWords: [("prove", "kanıtlamak"), ("provide", "sağlamak"), ("promote", "teşvik etmek"), ("protect", "korumak")],
            nuanceNoteTR: "\"Prevent\" genel bir engelleme fiilidir. \"Prohibit\" resmî olarak yasaklamak, \"hinder\" bir şeyi zorlaştırmak, \"avoid\" ise bir şeyden uzak durmak anlamına gelir.",
            isBoss: true
        ),
        SynonymCluster(
            id: "onemli",
            meaningFamilyTR: "önemli",
            correctWords: [("important", "önemli"), ("significant", "önemli"), ("crucial", "hayati"), ("vital", "hayati"), ("essential", "zorunlu")],
            wrongWords: [("minor", "önemsiz"), ("ordinary", "sıradan"), ("irrelevant", "alakasız"), ("weak", "zayıf")],
            nuanceNoteTR: "\"Crucial\" ve \"vital\" en güçlü vurguyu taşır; bir şeyin olmazsa olmaz olduğunu anlatır."
        ),
        SynonymCluster(
            id: "gostermek",
            meaningFamilyTR: "göstermek / ortaya koymak",
            correctWords: [("show", "göstermek"), ("reveal", "ortaya çıkarmak"), ("indicate", "belirtmek"), ("demonstrate", "göstermek")],
            wrongWords: [("hide", "saklamak"), ("ignore", "görmezden gelmek"), ("reduce", "azaltmak"), ("prevent", "önlemek")],
            nuanceNoteTR: "\"Reveal\" gizli bir şeyi ortaya çıkarırken, \"demonstrate\" bir kanıtla göstermek anlamına gelir."
        ),
        SynonymCluster(
            id: "iddia",
            meaningFamilyTR: "iddia etmek / savunmak",
            correctWords: [("claim", "iddia etmek"), ("argue", "savunmak"), ("assert", "ileri sürmek"), ("maintain", "savunmak")],
            wrongWords: [("complain", "şikayet etmek"), ("explain", "açıklamak"), ("obtain", "elde etmek"), ("avoid", "kaçınmak")],
            nuanceNoteTR: "Bu grup, kanıtlanmamış bir görüşü ısrarla savunmayı anlatır — \"complain\" ile karıştırılmamalı."
        ),
        SynonymCluster(
            id: "desteklemek",
            meaningFamilyTR: "desteklemek",
            correctWords: [("support", "desteklemek"), ("back", "desteklemek"), ("assist", "yardım etmek"), ("reinforce", "güçlendirmek")],
            wrongWords: [("suppose", "varsaymak"), ("oppose", "karşı çıkmak"), ("prevent", "önlemek"), ("reduce", "azaltmak")],
            nuanceNoteTR: "\"Suppose\" kulağa benzer gelse de \"desteklemek\" değil, \"varsaymak\" demektir — klasik bir YDS tuzağıdır."
        ),
        SynonymCluster(
            id: "eldeetmek",
            meaningFamilyTR: "elde etmek / kazanmak",
            correctWords: [("obtain", "elde etmek"), ("gain", "kazanmak"), ("acquire", "edinmek"), ("achieve", "başarmak")],
            wrongWords: [("require", "gerektirmek"), ("avoid", "kaçınmak"), ("maintain", "sürdürmek"), ("contain", "içermek")],
            nuanceNoteTR: "\"Achieve\" genelde çaba sonucu bir hedefe ulaşmayı, \"acquire\" ise zamanla bir şeyi edinmeyi anlatır."
        ),
        SynonymCluster(
            id: "sebepolmak",
            meaningFamilyTR: "sebep olmak / yol açmak",
            correctWords: [("cause", "sebep olmak"), ("lead to", "yol açmak"), ("result in", "sonuçlanmak"), ("bring about", "neden olmak")],
            wrongWords: [("prevent", "önlemek"), ("avoid", "kaçınmak"), ("reduce", "azaltmak"), ("hide", "saklamak")],
            nuanceNoteTR: "Bu grup neden-sonuç ilişkisini kurar; YDS okuma parçalarında çok sık geçer."
        ),
        SynonymCluster(
            id: "devametmek",
            meaningFamilyTR: "devam etmek / sürdürmek",
            correctWords: [("continue", "devam etmek"), ("maintain", "sürdürmek"), ("sustain", "sürdürmek"), ("persist", "ısrar etmek")],
            wrongWords: [("contain", "içermek"), ("stop", "durdurmak"), ("prevent", "önlemek"), ("reduce", "azaltmak")],
            nuanceNoteTR: "\"Persist\" genelde zorluğa rağmen devam etmeyi, \"sustain\" ise bir durumu uzun süre korumayı anlatır."
        ),
    ]

    /// One round's wave order: a few random non-boss clusters, then the boss last.
    static func samplePlaylist(waveCount: Int = 4) -> [SynonymCluster] {
        let boss = all.first { $0.isBoss } ?? all.last!
        let normal = all.filter { !$0.isBoss }.shuffled().prefix(waveCount)
        return Array(normal) + [boss]
    }
}
