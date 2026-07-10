import SpriteKit

/// Finds the largest font size at which no single word of `text` exceeds
/// `maxWidth` — so labels shrink to fit instead of breaking mid-word
/// ("ambiguous" must never render as "ambiguo / us").
enum LabelFitter {
    static func fontSize(
        for text: String,
        fontName: String = "AvenirNext-Bold",
        maxWidth: CGFloat,
        base: CGFloat,
        min minSize: CGFloat
    ) -> CGFloat {
        let longestWord = text
            .components(separatedBy: " ")
            .max(by: { $0.count < $1.count }) ?? text

        let probe = SKLabelNode(text: longestWord)
        probe.fontName = fontName
        var size = base
        // Small safety margin: SKLabelNode's real (wrapped) layout can measure
        // a hair wider than this unconstrained single-line probe.
        let safeWidth = maxWidth - 4
        while size > minSize {
            probe.fontSize = size
            if probe.frame.width <= safeWidth { return size }
            size -= 0.5
        }
        return minSize
    }
}
