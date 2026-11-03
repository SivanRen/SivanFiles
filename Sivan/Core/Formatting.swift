import Foundation

enum Fmt {

    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.isAdaptive = true
        f.zeroPadsFractionDigits = false
        return f
    }()

    static func size(_ bytes: Int64) -> String {
        if bytes <= 0 { return "0 KB" }
        if bytes < 1024 { return "\(bytes) B" }
        return sizeFormatter.string(fromByteCount: bytes)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    static func date(_ d: Date) -> String { dateFormatter.string(from: d) }

    static func shortDate(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return "今天 " + f.string(from: d)
        }
        if cal.isDateInYesterday(d) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return "昨天 " + f.string(from: d)
        }
        return shortDateFormatter.string(from: d)
    }

    /// 从 POSIX 权限位生成 -rw-r--r-- 形式
    static func permissions(_ mode: Int) -> String {
        let types = ["---", "--x", "-w-", "-wx", "r--", "r-x", "rw-", "rwx"]
        let owner = (mode >> 6) & 0x7
        let group = (mode >> 3) & 0x7
        let other = mode & 0x7
        return "-" + types[owner] + types[group] + types[other]
    }
}
