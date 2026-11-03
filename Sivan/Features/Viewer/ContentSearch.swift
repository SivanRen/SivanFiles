import SwiftUI
import UIKit

// MARK: - 搜索选项

struct SearchOptions: Equatable {
    var caseSensitive = false
    var wholeWord = false
    var useRegex = false

    var isDefault: Bool { !caseSensitive && !wholeWord && !useRegex }
}

// MARK: - 单条命中

struct SearchMatch: Identifiable {

    let id: Int
    /// 在全文中的位置
    let range: NSRange
    /// 行号（从 1 开始）
    let line: Int
    /// 该行完整内容（不含换行符）
    let lineText: String
    /// 命中位置在该行内的范围
    let highlightInLine: NSRange

    /// 行太长时只截取命中位置附近的一段，保证高亮部分一定看得见
    func window(leading: Int = 24, trailing: Int = 90)
        -> (before: String, match: String, after: String) {

        let ns = lineText as NSString
        guard ns.length > 0, highlightInLine.location != NSNotFound,
              NSMaxRange(highlightInLine) <= ns.length else {
            return ("", "", lineText)
        }

        let start = max(0, highlightInLine.location - leading)
        let end = min(ns.length, NSMaxRange(highlightInLine) + trailing)

        var before = ns.substring(
            with: NSRange(location: start, length: max(0, highlightInLine.location - start))
        )
        if start == 0 {
            // 行首的缩进很占地方，直接吃掉
            before = String(before.drop(while: { $0 == " " || $0 == "\t" }))
        }

        let match = ns.substring(with: highlightInLine)
        let after = ns.substring(
            with: NSRange(
                location: NSMaxRange(highlightInLine),
                length: max(0, end - NSMaxRange(highlightInLine))
            )
        )

        return (
            start > 0 ? "…" + before : before,
            match,
            end < ns.length ? after + "…" : after
        )
    }
}

// MARK: - 滚动目标

struct SearchScroll: Equatable {
    let range: NSRange
    let token: UUID
}

// MARK: - 搜索引擎

enum ContentSearch {

    /// 单次搜索最多记多少条，防止超大文件 + 极短关键词把内存和列表拖死
    static let limit = 2000

    static func find(
        _ query: String,
        in text: String,
        options: SearchOptions
    ) -> (matches: [SearchMatch], error: String?) {

        guard !query.isEmpty else { return ([], nil) }

        var pattern = query
        if !options.useRegex {
            pattern = NSRegularExpression.escapedPattern(for: query)
            if options.wholeWord {
                // 用零宽断言包一层，比 \b 更贴合「全字匹配」的直觉
                pattern = "(?<![A-Za-z0-9_])" + pattern + "(?![A-Za-z0-9_])"
            }
        }

        var regexOptions: NSRegularExpression.Options = []
        if !options.caseSensitive { regexOptions.insert(.caseInsensitive) }

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: regexOptions)
        } catch {
            return ([], "正则表达式无效")
        }

        let ns = text as NSString
        guard ns.length > 0 else { return ([], nil) }

        let index = LineIndex(text: ns)
        var matches: [SearchMatch] = []
        matches.reserveCapacity(min(limit, 256))

        regex.enumerateMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        ) { result, _, stop in
            guard let result, result.range.length > 0 else { return }
            guard matches.count < limit else {
                stop.pointee = true
                return
            }

            let hit = index.line(for: result.range.location)
            let lineRaw = ns.substring(with: hit.range)
            let lineText = lineRaw.hasSuffix("\n")
                ? String(lineRaw.dropLast()).replacingOccurrences(of: "\r", with: "")
                : lineRaw.replacingOccurrences(of: "\r", with: "")

            matches.append(
                SearchMatch(
                    id: matches.count,
                    range: result.range,
                    line: hit.line,
                    lineText: lineText,
                    highlightInLine: NSRange(
                        location: result.range.location - hit.range.location,
                        length: result.range.length
                    )
                )
            )
        }

        return (matches, nil)
    }

    /// 把命中位置涂成高亮，当前选中的那条颜色更重
    static func highlighted(
        _ base: NSAttributedString,
        matches: [SearchMatch],
        current: Int
    ) -> NSAttributedString {

        guard !matches.isEmpty else { return base }

        let output = NSMutableAttributedString(attributedString: base)
        let normal = UIColor.systemYellow.withAlphaComponent(0.30)
        let active = UIColor.systemOrange.withAlphaComponent(0.78)

        for match in matches where NSMaxRange(match.range) <= output.length {
            output.addAttribute(.backgroundColor, value: normal, range: match.range)
        }
        if matches.indices.contains(current) {
            let match = matches[current]
            if NSMaxRange(match.range) <= output.length {
                output.addAttribute(.backgroundColor, value: active, range: match.range)
            }
        }
        return output
    }
}

// MARK: - 行索引（把字符位置映射到行号）

private struct LineIndex {

    private let text: NSString
    private let starts: [Int]

    init(text: NSString) {
        self.text = text
        let length = text.length
        var starts: [Int] = [0]
        guard length > 0 else {
            self.starts = starts
            return
        }

        var buffer = [unichar](repeating: 0, count: min(length, 1 << 16))
        var offset = 0
        while offset < length {
            let chunk = min(buffer.count, length - offset)
            text.getCharacters(&buffer, range: NSRange(location: offset, length: chunk))
            for i in 0..<chunk where buffer[i] == 10 {
                starts.append(offset + i + 1)
            }
            offset += chunk
        }
        self.starts = starts
    }

    /// 返回行号（从 1 开始）与该行在全文中的范围（含行尾换行符）
    func line(for location: Int) -> (line: Int, range: NSRange) {
        guard starts.count > 1 else {
            return (1, NSRange(location: 0, length: text.length))
        }
        var low = 0
        var high = starts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if starts[mid] <= location {
                low = mid
            } else {
                high = mid - 1
            }
        }
        let start = starts[low]
        let end = low + 1 < starts.count ? starts[low + 1] : text.length
        return (low + 1, NSRange(location: start, length: max(0, end - start)))
    }
}

// MARK: - 搜索状态（预览页与内容页共享）

final class ContentSearchStore: ObservableObject {

    @Published var isActive = false
    @Published var query = ""
    @Published var options = SearchOptions()
    @Published var matches: [SearchMatch] = []
    @Published var current = 0
    @Published var errorText: String?
    @Published var showList = false
    /// 换文件时 +1，通知内容页重跑一次搜索
    @Published var revision = 0

    /// 内容页据此判断要不要重新搜索
    var key: String {
        "\(query)#\(options.caseSensitive)\(options.wholeWord)\(options.useRegex)#\(revision)"
    }

    var hasResults: Bool { !matches.isEmpty }

    func open() {
        showList = false
        isActive = true
    }

    func close() {
        isActive = false
        showList = false
        query = ""
        matches = []
        current = 0
        errorText = nil
    }

    func apply(_ matches: [SearchMatch], error: String?) {
        self.matches = matches
        self.errorText = error
        self.current = 0
    }

    func step(_ delta: Int) {
        guard !matches.isEmpty else { return }
        current = (current + delta + matches.count) % matches.count
    }

    func select(_ index: Int) {
        guard matches.indices.contains(index) else { return }
        current = index
        showList = false
    }
}

// MARK: - 选项小胶囊

struct SearchOptionChip: View {

    let title: String
    let isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isOn ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(isOn ? Theme.inverse : Theme.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isOn ? AnyShapeStyle(Theme.text) : AnyShapeStyle(.ultraThinMaterial))
                )
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 搜索结果列表（半页）

struct SearchResultsPanel: View {

    @ObservedObject var store: ContentSearchStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            if store.matches.isEmpty {
                empty
            } else {
                list
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("搜索结果")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.text)

            Text("\(store.matches.count)")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)

            Spacer()

            Button {
                store.showList = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Theme.veil(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .thin))
                .foregroundStyle(Theme.textTertiary)
            Text(store.errorText ?? "没有匹配的内容")
                .font(.system(size: 11.5))
                .foregroundStyle(store.errorText == nil ? Theme.textTertiary : Theme.danger)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.matches) { match in
                        row(match)
                        Hairline().padding(.leading, 52)
                    }
                }
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                proxy.scrollTo(store.current, anchor: .center)
            }
        }
    }

    private func row(_ match: SearchMatch) -> some View {
        let parts = match.window()
        let isCurrent = store.current == match.id

        return Button {
            store.select(match.id)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(match.line)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 32, alignment: .trailing)

                (
                    Text(parts.before).foregroundColor(Theme.textSecondary)
                    + Text(parts.match).foregroundColor(Theme.text).bold()
                    + Text(parts.after).foregroundColor(Theme.textSecondary)
                )
                .font(.system(size: 11.5, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(isCurrent ? Theme.veil(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
