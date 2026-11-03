import SwiftUI
import UIKit

// MARK: - 语法着色

/// 语法着色用色：深色一套、浅色一套，避免浅色模式下代码「白底白字」
struct SyntaxPalette {

    let keyword: UIColor
    let string: UIColor
    let number: UIColor
    let comment: UIColor
    let plain: UIColor
    let tag: UIColor
    let attribute: UIColor
    let meta: UIColor

    static func forScheme(_ scheme: ColorScheme) -> SyntaxPalette {
        if scheme == .light {
            return SyntaxPalette(
                keyword: UIColor(hex: 0x8B3FB8),
                string: UIColor(hex: 0x1B7A3E),
                number: UIColor(hex: 0xA85500),
                comment: UIColor(hex: 0x8A8F99),
                plain: UIColor(hex: 0x23232B),
                tag: UIColor(hex: 0x0A6CFF),
                attribute: UIColor(hex: 0x0E7490),
                meta: UIColor(hex: 0x9A3412)
            )
        }
        return SyntaxPalette(
            keyword: UIColor(hex: 0xC792EA),
            string: UIColor(hex: 0x9CDC7E),
            number: UIColor(hex: 0xF2A45C),
            comment: UIColor(hex: 0x6B7280),
            plain: UIColor(hex: 0xD6D9E0),
            tag: UIColor(hex: 0x6FA8FF),
            attribute: UIColor(hex: 0x5FD3C4),
            meta: UIColor(hex: 0xE5A0C8)
        )
    }
}

enum SyntaxHighlighter {

    /// 太长的文件不做着色，避免正则扫全篇卡住
    private static let sizeLimit = 320_000

    static func make(
        _ code: String,
        language: CodeLanguage,
        fontSize: CGFloat,
        scheme: ColorScheme
    ) -> NSAttributedString {

        let palette = SyntaxPalette.forScheme(scheme)
        let regular = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.lineBreakMode = .byWordWrapping

        let result = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: regular,
                .foregroundColor: palette.plain,
                .paragraphStyle: paragraph
            ]
        )

        guard !language.isPlain, code.count < sizeLimit else { return result }

        let full = NSRange(location: 0, length: (code as NSString).length)
        let styles = StyleFonts(
            regular: regular,
            bold: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            italic: italicFont(size: fontSize, weight: .regular)
        )

        for rule in rules(for: language) {
            apply(
                pattern: rule.pattern,
                style: rule.style,
                to: result,
                source: code,
                range: full,
                palette: palette,
                fonts: styles
            )
        }

        return result
    }

    // MARK: 规则表

    /// 顺序很重要：后面的规则会盖住前面的（注释永远最后覆盖）
    static func rules(for language: CodeLanguage) -> [(pattern: String, style: TokenStyle)] {
        let spec = language.spec
        var rules: [(pattern: String, style: TokenStyle)] = []

        if !spec.keywords.isEmpty {
            let words = spec.keywords
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .sorted { $0.count > $1.count }
            rules.append(("\\b(?:" + words.joined(separator: "|") + ")\\b", .keyword))
        }

        rules.append(("\\b\\d+(?:\\.\\d+)?\\b", .number))

        for quote in spec.stringQuotes {
            rules.append((stringPattern(quote), .string))
        }

        for rule in spec.extraRules {
            rules.append((rule.pattern, rule.style))
        }

        if let block = spec.blockComment {
            let open = NSRegularExpression.escapedPattern(for: block.open)
            let close = NSRegularExpression.escapedPattern(for: block.close)
            rules.append((open + "[\\s\\S]*?" + close, .comment))
        }

        for token in spec.lineComment {
            rules.append((NSRegularExpression.escapedPattern(for: token) + "[^\\n]*", .comment))
        }

        return rules
    }

    private static func stringPattern(_ quote: Character) -> String {
        switch quote {
        case "\"":
            return #"\""# + #"(?:\\.|[^"\\\n])*"# + #"\""#
        case "'":
            return #"'(?:\\.|[^'\\\n])*'"#
        default:
            return #"`(?:\\.|[^`\\\n])*`"#
        }
    }

    // MARK: 上色

    private struct StyleFonts {
        let regular: UIFont
        let bold: UIFont
        let italic: UIFont
    }

    private static func italicFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) else {
            return base
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func apply(
        pattern: String,
        style: TokenStyle,
        to text: NSMutableAttributedString,
        source: String,
        range: NSRange,
        palette: SyntaxPalette,
        fonts: StyleFonts
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        regex.enumerateMatches(in: source, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range, matchRange.length > 0,
                  NSMaxRange(matchRange) <= text.length else { return }

            switch style {
            case .keyword:
                text.addAttribute(.foregroundColor, value: palette.keyword, range: matchRange)
                text.addAttribute(.font, value: fonts.bold, range: matchRange)
            case .string:
                text.addAttribute(.foregroundColor, value: palette.string, range: matchRange)
            case .number:
                text.addAttribute(.foregroundColor, value: palette.number, range: matchRange)
            case .comment:
                text.addAttribute(.foregroundColor, value: palette.comment, range: matchRange)
                text.addAttribute(.font, value: fonts.italic, range: matchRange)
            case .tag:
                text.addAttribute(.foregroundColor, value: palette.tag, range: matchRange)
            case .attribute:
                text.addAttribute(.foregroundColor, value: palette.attribute, range: matchRange)
            case .key:
                text.addAttribute(.foregroundColor, value: palette.meta, range: matchRange)
                text.addAttribute(.font, value: fonts.bold, range: matchRange)
            case .meta:
                text.addAttribute(.foregroundColor, value: palette.meta, range: matchRange)
            }
        }
    }
}


// MARK: - 只读文本视图

struct CodeTextView: UIViewRepresentable {

    let attributed: NSAttributedString
    var topInset: CGFloat = 62
    var bottomInset: CGFloat = 150
    /// 搜索命中项：需要滚动到这条
    var scrollTarget: SearchScroll?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(
            top: topInset, left: 14, bottom: bottomInset, right: 14
        )
        textView.attributedText = attributed
        textView.contentInsetAdjustmentBehavior = .never
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.attributedText != attributed {
            textView.attributedText = attributed
        }
        if textView.textContainerInset.top != topInset {
            textView.textContainerInset.top = topInset
        }
        if textView.textContainerInset.bottom != bottomInset {
            textView.textContainerInset.bottom = bottomInset
        }
        guard let target = scrollTarget,
              context.coordinator.lastToken != target.token else { return }

        context.coordinator.lastToken = target.token
        let range = target.range

        // scrollRangeToVisible 在带大 textContainerInset 的只读 UITextView 上常常
        // 贴边甚至不动（尤其底部留白很大时），这里用 layoutManager 直接算出命中行的
        // 真实 y，再一次性把这一行送到可视区上方约三分之一处。
        DispatchQueue.main.async {
            guard let attr = textView.attributedText,
                  NSMaxRange(range) <= attr.length else { return }
            textView.layoutIfNeeded()

            let manager = textView.layoutManager
            let glyphs = manager.glyphRange(
                forCharacterRange: range, actualCharacterRange: nil
            )
            var rect = manager.boundingRect(
                forGlyphRange: glyphs, in: textView.textContainer
            )
            rect.origin.y += textView.textContainerInset.top

            let usable = max(
                140,
                textView.bounds.height - textView.textContainerInset.top - 100
            )
            let desired = rect.midY - usable * 0.32
            let ceiling = max(0, textView.contentSize.height - textView.bounds.height)
            let y = min(max(desired, 0), ceiling)

            UIView.animate(withDuration: 0.26, delay: 0, options: .curveEaseOut) {
                textView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
            }
        }
    }

    final class Coordinator {
        var lastToken: UUID?
    }
}

// MARK: - 代码 / 文本页面

struct CodePage: View {

    let url: URL
    var topInset: CGFloat = 62
    /// 当前页在前台时才做搜索与高亮，避免相邻页抢搜索结果
    var isActive: Bool = true

    @EnvironmentObject private var search: ContentSearchStore
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var languagePreference = LanguagePreference.shared

    @State private var text: String?
    @State private var failed = false
    @State private var base: NSAttributedString?
    @State private var rendered: NSAttributedString?
    @State private var loadToken = 0
    @State private var scrollTarget: SearchScroll?

    private var language: CodeLanguage {
        languagePreference.effective(for: url)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            content

            if search.isActive && isActive {
                bottomBar
            }

            if search.isActive && isActive && search.showList {
                resultsLayer
            }
        }
        .task { load() }
        .task(id: searchTaskID) { await runSearch() }
        .onChange(of: search.current) { _, _ in
            applyHighlights()
            scrollToCurrent()
        }
        .onChange(of: search.showList) { _, open in
            // 从结果列表里点了一条（current 可能没变），关上列表后补一次定位
            if !open { scrollToCurrent() }
        }
        .onChange(of: scheme) { _, _ in
            buildBase()
            applyHighlights()
        }
        .onChange(of: languagePreference.overrides) { _, _ in
            // 在详情里换了解析语言，重新着色
            buildBase()
            applyHighlights()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let text {
            if text.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc")
                        .font(.system(size: 34, weight: .thin))
                        .foregroundStyle(Theme.textTertiary)
                    Text("空文件")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                CodeTextView(
                    attributed: rendered ?? NSAttributedString(string: text),
                    topInset: topInset + (search.isActive && isActive ? 96 : 0),
                    bottomInset: search.isActive && isActive ? 380 : 150,
                    scrollTarget: scrollTarget
                )
                .ignoresSafeArea()
            }
        } else if failed {
            VStack(spacing: 10) {
                Image(systemName: "text.badge.xmark")
                    .font(.system(size: 34, weight: .thin))
                    .foregroundStyle(Theme.textTertiary)
                Text("无法以文本方式打开")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text("这可能是二进制或其他特殊编码的文件")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        } else {
            ProgressView().tint(Theme.textSecondary)
        }
    }

    // MARK: - 底部：结果列表（左） / 上一条·下一条（右）

    @ViewBuilder
    private var bottomBar: some View {
        if search.hasResults {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        search.showList = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(search.matches.count)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())

                    Spacer(minLength: 8)

                    HStack(spacing: 0) {
                        Button {
                            search.step(-1)
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.text)
                                .frame(width: 38, height: 36)
                        }
                        .buttonStyle(PressableStyle())

                        Text("\(search.current + 1)/\(search.matches.count)")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(minWidth: 44)

                        Button {
                            search.step(1)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.text)
                                .frame(width: 38, height: 36)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 22)
            }
            .transition(.opacity)
        }
    }

    private var resultsLayer: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture { search.showList = false }

                SearchResultsPanel(store: search)
                    .frame(height: max(240, proxy.size.height * 0.5))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - 搜索流程

    private var searchTaskID: String {
        "\(search.key)#\(isActive ? 1 : 0)#\(loadToken)"
    }

    private func runSearch() async {
        guard isActive else { return }
        guard search.isActive, let text, !text.isEmpty else {
            // 搜索关掉了：把高亮擦回原始着色的样子
            applyHighlights()
            return
        }
        guard !search.query.isEmpty else {
            search.matches = []
            search.errorText = nil
            applyHighlights()
            return
        }

        // 打字时防抖，别每敲一下就全量扫一遍
        do {
            try await Task.sleep(nanoseconds: 200_000_000)
        } catch {
            return
        }

        let result = ContentSearch.find(search.query, in: text, options: search.options)
        search.apply(result.matches, error: result.error)
        applyHighlights()
        scrollToCurrent()
    }

    private func scrollToCurrent() {
        guard search.isActive, search.hasResults,
              search.matches.indices.contains(search.current) else {
            scrollTarget = nil
            return
        }
        scrollTarget = SearchScroll(
            range: search.matches[search.current].range,
            token: UUID()
        )
    }

    /// 语法着色只做一次，搜索高亮叠在上面，翻上一条/下一条时不必重新着色
    private func buildBase() {
        guard let text else { return }
        base = SyntaxHighlighter.make(
            text,
            language: language,
            fontSize: CGFloat(AppSettings.shared.codeFontSize),
            scheme: scheme
        )
    }

    private func applyHighlights() {
        guard let base else { return }
        guard search.isActive, isActive else {
            rendered = base
            return
        }
        rendered = ContentSearch.highlighted(
            base,
            matches: search.matches,
            current: search.current
        )
    }

    private func load() {
        guard text == nil, !failed else { return }
        if let content = FileStore.shared.readText(url) {
            text = content
            buildBase()
            applyHighlights()
            loadToken += 1
        } else {
            failed = true
        }
    }
}
