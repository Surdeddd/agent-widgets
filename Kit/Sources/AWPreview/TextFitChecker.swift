import AppKit
import AWKit
import AWSchema
import SwiftUI

@MainActor
final class TextFitCollector {
    var fits: [AWTextFit] = []
    var content: CGSize = .zero
    var blocks: [AWBlock] = []
}

struct LayoutSample {
    let fits: [AWTextFit]
    let content: CGSize
    let blocks: [AWBlock]
}

struct ContentOverflow {
    let extra: CGFloat
    let vertical: Bool
}

@MainActor
enum TextFitChecker {
    static func collect(_ view: some View, size: CGSize) -> LayoutSample {
        let collector = TextFitCollector()
        let probe = view
            .frame(width: size.width, height: size.height)
            .onPreferenceChange(AWTextFitKey.self) { collector.fits = $0 }
            .onPreferenceChange(AWContentSizeKey.self) { collector.content = $0 }
            .onPreferenceChange(AWBlockKey.self) { collector.blocks = $0 }
        _ = PNG.render(probe, scale: 1)
        return LayoutSample(fits: collector.fits, content: collector.content, blocks: collector.blocks)
    }

    static func contentOverflow(_ content: CGSize, family: Family) -> ContentOverflow? {
        let inset = AWMetrics.padding(for: family) * 2
        let height = content.height - (family.size.height - inset)
        let width = content.width - (family.size.width - inset)
        let extra = max(height, width)
        return extra > 1 ? ContentOverflow(extra: extra, vertical: height >= width) : nil
    }

    /// The three biggest named parts along the overflowing axis, for example "AWSparkline 96 pt · AWList, 5 rows 140 pt".
    static func largest(_ blocks: [AWBlock], vertical: Bool) -> String {
        var seen = Set<String>()
        return blocks
            .sorted { (vertical ? $0.size.height : $0.size.width) > (vertical ? $1.size.height : $1.size.width) }
            .filter { seen.insert($0.name).inserted }
            .prefix(3)
            .map { "\($0.name) \(Int((vertical ? $0.size.height : $0.size.width).rounded())) pt" }
            .joined(separator: " · ")
    }

    static func issues(for fits: [AWTextFit], scenario: String) -> [Issue] {
        var issues: [Issue] = []
        var seen = Set<String>()
        for fit in fits where fit.width > 1 {
            let needed = neededLines(fit)
            guard needed > fit.lines, seen.insert(fit.text).inserted else { continue }
            let preview = fit.text.count > 40 ? String(fit.text.prefix(40)) + "…" : fit.text
            issues.append(Issue(
                code: IssueCode.truncation,
                severity: scenario == "default" ? .error : .warning,
                message: L10n.pick(
                    en: "\"\(preview)\" needs \(needed) lines at \(fit.role.rawValue) size but gets \(fit.lines) in \(fit.family.rawValue)",
                    ru: "\"\(preview)\" нужно \(needed) строк в стиле \(fit.role.rawValue), а в \(fit.family.rawValue) есть \(fit.lines)"
                ),
                hint: L10n.pick(
                    en: "Allow more lines, shorten the text in the feed, or use a smaller role",
                    ru: "Дай больше строк, укороти текст в feed или возьми стиль мельче"
                )
            ))
        }
        for fit in fits where AWType.size(fit.role, fit.family) * AWType.minimumScale(fit.role) < 8.5 {
            guard seen.insert("tiny:\(fit.text)").inserted else { continue }
            issues.append(Issue(
                code: IssueCode.tinyText,
                severity: .warning,
                message: L10n.pick(en: "\"\(fit.text.prefix(30))\" can shrink below 8.5 pt", ru: "\"\(fit.text.prefix(30))\" может сжаться мельче 8,5 pt")
            ))
        }
        return issues
    }

    static func neededLines(_ fit: AWTextFit) -> Int {
        let scale = AWType.minimumScale(fit.role)
        let size = AWType.size(fit.role, fit.family) * scale
        var font = NSFont.systemFont(ofSize: size, weight: nsWeight(AWType.weight(fit.role)))
        if AWType.design(fit.role) == .rounded, let rounded = font.fontDescriptor.withDesign(.rounded) {
            font = NSFont(descriptor: rounded, size: size) ?? font
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .kern: AWType.tracking(fit.role, fit.family) * scale]
        let single = ceil(font.ascender - font.descender + font.leading)
        let rect = (fit.text as NSString).boundingRect(
            with: CGSize(width: fit.width + 0.5, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return max(1, Int(ceil(rect.height / single - 0.05)))
    }

    private static func nsWeight(_ weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .bold: .bold
        case .semibold: .semibold
        case .medium: .medium
        case .light: .light
        default: .regular
        }
    }
}
