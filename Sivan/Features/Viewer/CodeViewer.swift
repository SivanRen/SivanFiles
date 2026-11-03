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

    static func forScheme(_ scheme: ColorScheme) -> SyntaxPalette {
        if scheme == .light {
            return SyntaxPalette(
                keyword: UIColor(hex: 0x8B3FB8),
                string: UIColor(hex: 0x1B7A3E),
                number: UIColor(hex: 0xA85500),
                comment: UIColor(hex: 0x8A8F99),
                plain: UIColor(hex: 0x23232B)
            )
        }
        return SyntaxPalette(
            keyword: UIColor(hex: 0xC792EA),
            string: UIColor(hex: 0x9CDC7E),
            number: UIColor(hex: 0xF2A45C),
            comment: UIColor(hex: 0x6B7280),
            plain: UIColor(hex: 0xD6D9E0)
        )
    }
}

enum SyntaxHighlighter {

    private static let keywords = [
        "func", "let", "var", "if", "else", "guard", "for", "while", "repeat", "return", "switch", "case",
        "default", "break", "continue", "struct", "class", "enum", "protocol", "extension", "import",
        "public", "private", "fileprivate", "internal", "static", "final", "override", "init", "deinit",
        "void", "int", "long", "short", "char", "float", "double", "unsigned", "signed", "const",
        "unsigned", "typedef", "sizeof", "include", "define", "ifdef", "ifndef", "endif", "pragma",
        "new", "delete", "try", "catch", "throw", "throws", "async", "await", "def", "end", "elif",
        "lambda", "pass", "None", "True", "False", "nil", "self", "super", "this", "null", "true", "false",
        "function", "typeof", "instanceof", "export", "from", "require", "module", "interface", "type",
        "package", "namespace", "using", "template", "typename", "virtual", "inline", "extern", "volatile"
    ]

    static func make(
        _ code: String,
        ext: String,
        fontSize: CGFloat,
        topInset: CGFloat,
        scheme: ColorScheme
    ) -> NSAttributedString {
        let palette = SyntaxPalette.forScheme(scheme)
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.lineBreakMode = .byWordWrapping

        let result = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: font,
                .foregroundColor: palette.plain,
                .paragraphStyle: paragraph
            ]
        )

        let plainExtensions: Set<String> = ["txt", "text", "log", "md", "markdown", "csv", "tsv"]
        guard !plainExtensions.contains(ext), code.count < 320_000 else { return result }

        let full = NSRange(location: 0, length: (code as NSString).length)

        // 1) 关键字
        let keywordPattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        apply(pattern: keywordPattern, color: palette.keyword, to: result, source: code, range: full)

        // 2) 数字
        apply(pattern: "\\b\\d+(\\.\\d+)?\\b", color: palette.number, to: result, source: code, range: full)

        // 3) 字符串
        apply(
            pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'",
            color: palette.string, to: result, source: code, range: full
        )

        // 4) 注释（最后覆盖）
        apply(
            pattern: "//[^\\n]*|/\\*[\\s\\S]*?\\*/",
            color: palette.comment, to: result, source: code, range: full
        )

        return result
    }

    private static func apply(
        pattern: String,
        color: UIColor,
        to text: NSMutableAttributedString,
        source: String,
        range: NSRange
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        regex.enumerateMatches(in: source, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range, matchRange.location != NSNotFound else { return }
            text.addAttribute(.foregroundColor, value: color, range: matchRange)
        }
    }
}

// MARK: - 只读文本视图

struct CodeTextView: UIViewRepresentable {

    let attributed: NSAttributedString
    var topInset: CGFloat = 62

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: topInset, left: 14, bottom: 150, right: 14)
        textView.attributedText = attributed
        textView.contentInsetAdjustmentBehavior = .never
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.attributedText != attributed {
            textView.attributedText = attributed
        }
    }
}

// MARK: - 代码 / 文本页面

struct CodePage: View {

    let url: URL
    var topInset: CGFloat = 62

    @Environment(\.colorScheme) private var scheme
    @State private var text: String?
    @State private var failed = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            content
        }
        .task { load() }
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
                    attributed: SyntaxHighlighter.make(
                        text,
                        ext: url.pathExtension.lowercased(),
                        fontSize: CGFloat(AppSettings.shared.codeFontSize),
                        topInset: topInset,
                        scheme: scheme
                    ),
                    topInset: topInset
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

    private func load() {
        guard text == nil, !failed else { return }
        if let content = FileStore.shared.readText(url) {
            text = content
        } else {
            failed = true
        }
    }
}
