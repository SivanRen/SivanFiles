import SwiftUI
import UIKit

// MARK: - 着色样式

enum TokenStyle {
    case keyword
    case string
    case number
    case comment
    case tag
    case attribute
    /// 对象键名（JSON / plist / 配置里的 key）
    case key
    case meta
}

// MARK: - 语言规则

struct LanguageSpec {
    var keywords: [String] = []
    var lineComment: [String] = []
    var blockComment: (open: String, close: String)? = nil
    var stringQuotes: [Character] = ["\"", "'"]
    /// 语言专属规则（HTML 标签、JSON 键名、CSS 属性…）
    var extraRules: [(pattern: String, style: TokenStyle)] = []
}

// MARK: - 语言

enum CodeLanguage: String, CaseIterable, Identifiable {

    case plain
    case swift, objectiveC, c, cpp, csharp, java, kotlin, go, rust
    case python, ruby, php, perl, lua, r, dart, scala, haskell
    case javascript, typescript, json, xml, html, css, scss
    case markdown, yaml, sql, shell, dockerfile, makefile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: return "纯文本（不高亮）"
        case .swift: return "Swift"
        case .objectiveC: return "Objective-C"
        case .c: return "C"
        case .cpp: return "C++"
        case .csharp: return "C#"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .go: return "Go"
        case .rust: return "Rust"
        case .python: return "Python"
        case .ruby: return "Ruby"
        case .php: return "PHP"
        case .perl: return "Perl"
        case .lua: return "Lua"
        case .r: return "R"
        case .dart: return "Dart"
        case .scala: return "Scala"
        case .haskell: return "Haskell"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .json: return "JSON"
        case .xml: return "XML / Plist"
        case .html: return "HTML"
        case .css: return "CSS"
        case .scss: return "SCSS / Less"
        case .markdown: return "Markdown"
        case .yaml: return "YAML"
        case .sql: return "SQL"
        case .shell: return "Shell"
        case .dockerfile: return "Dockerfile"
        case .makefile: return "Makefile"
        }
    }

    /// 快捷栏里显示的名字，尽量短
    var shortTitle: String {
        switch self {
        case .plain: return "纯文本"
        case .objectiveC: return "ObjC"
        case .javascript: return "JS"
        case .typescript: return "TS"
        case .markdown: return "MD"
        case .dockerfile: return "Docker"
        case .makefile: return "Make"
        default: return title
        }
    }

    var isPlain: Bool { self == .plain }

    static var pickerList: [CodeLanguage] {
        [
            .plain, .swift, .objectiveC, .c, .cpp, .csharp, .java, .kotlin, .go, .rust,
            .python, .ruby, .php, .perl, .lua, .javascript, .typescript, .json, .xml, .html,
            .css, .scss, .markdown, .yaml, .sql, .shell, .dockerfile, .makefile,
            .dart, .scala, .r, .haskell
        ]
    }

    var spec: LanguageSpec {
        switch self {
        case .plain:
            return LanguageSpec()

        case .swift:
            return LanguageSpec(
                keywords: [
                    "actor", "associatedtype", "async", "await", "break", "case", "catch", "class",
                    "continue", "convenience", "defer", "deinit", "do", "else", "enum", "extension",
                    "fallthrough", "fileprivate", "final", "for", "func", "guard", "if", "import",
                    "in", "indirect", "init", "inout", "internal", "is", "lazy", "let", "mutating",
                    "nonisolated", "open", "operator", "override", "private", "protocol", "public",
                    "repeat", "required", "rethrows", "return", "self", "Self", "some", "static",
                    "struct", "subscript", "super", "switch", "throw", "throws", "try", "typealias",
                    "var", "where", "while", "willSet", "didSet", "nil", "true", "false", "as",
                    "weak", "unowned", "any", "each", "consuming"
                ],
                lineComment: ["//"],
                blockComment: ("/*", "*/"),
                stringQuotes: ["\""],
                extraRules: [
                    ("@[A-Za-z_][A-Za-z0-9_]*", .attribute),
                    ("#[A-Za-z_][A-Za-z0-9_]*", .meta)
                ]
            )

        case .objectiveC:
            return Self.cFamily(
                keywords: [
                    "auto", "break", "case", "char", "const", "continue", "default", "do", "double",
                    "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long",
                    "register", "restrict", "return", "short", "signed", "sizeof", "static", "struct",
                    "switch", "typedef", "union", "unsigned", "void", "volatile", "while",
                    "id", "self", "super", "nil", "Nil", "BOOL", "YES", "NO", "instancetype",
                    "interface", "implementation", "protocol", "property", "synthesize", "end",
                    "nonatomic", "atomic", "strong", "weak", "copy", "assign", "retain", "readonly",
                    "readwrite", "nullable", "nonnull", "IBAction", "IBOutlet"
                ],
                hashRules: true
            )

        case .c:
            return Self.cFamily(
                keywords: [
                    "auto", "break", "case", "char", "const", "continue", "default", "do", "double",
                    "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long",
                    "register", "restrict", "return", "short", "signed", "sizeof", "static", "struct",
                    "switch", "typedef", "union", "unsigned", "void", "volatile", "while",
                    "NULL", "size_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t",
                    "int8_t", "int16_t", "int32_t", "int64_t", "bool", "true", "false"
                ],
                hashRules: true
            )

        case .cpp:
            return Self.cFamily(
                keywords: [
                    "alignas", "alignof", "auto", "bool", "break", "case", "catch", "char", "class",
                    "const", "constexpr", "continue", "decltype", "default", "delete", "do", "double",
                    "else", "enum", "explicit", "export", "extern", "false", "float", "for", "friend",
                    "goto", "if", "inline", "int", "long", "mutable", "namespace", "new", "noexcept",
                    "nullptr", "operator", "override", "private", "protected", "public", "register",
                    "return", "short", "signed", "sizeof", "static", "static_cast", "struct", "switch",
                    "template", "this", "throw", "true", "try", "typedef", "typename", "union",
                    "unsigned", "using", "virtual", "void", "volatile", "while", "final",
                    "std", "string", "vector", "map", "set", "shared_ptr", "unique_ptr", "size_t"
                ],
                hashRules: true
            )

        case .csharp:
            return Self.cFamily(
                keywords: [
                    "abstract", "as", "async", "await", "base", "bool", "break", "byte", "case",
                    "catch", "char", "checked", "class", "const", "continue", "decimal", "default",
                    "delegate", "do", "double", "else", "enum", "event", "explicit", "extern", "false",
                    "finally", "fixed", "float", "for", "foreach", "get", "goto", "if", "implicit",
                    "in", "int", "interface", "internal", "is", "lock", "long", "namespace", "new",
                    "null", "object", "operator", "out", "override", "params", "private", "protected",
                    "public", "readonly", "ref", "return", "sealed", "set", "short", "sizeof",
                    "static", "string", "struct", "switch", "this", "throw", "true", "try", "typeof",
                    "uint", "ulong", "unchecked", "using", "var", "virtual", "void", "volatile", "while"
                ]
            )

        case .java:
            return Self.cFamily(
                keywords: [
                    "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class",
                    "const", "continue", "default", "do", "double", "else", "enum", "extends", "final",
                    "finally", "float", "for", "goto", "if", "implements", "import", "instanceof",
                    "int", "interface", "long", "native", "new", "null", "package", "private",
                    "protected", "public", "record", "return", "sealed", "short", "static", "strictfp",
                    "super", "switch", "synchronized", "this", "throw", "throws", "transient", "true",
                    "try", "var", "void", "volatile", "while", "false"
                ]
            )

        case .kotlin:
            return Self.cFamily(
                keywords: [
                    "as", "break", "class", "companion", "const", "constructor", "continue", "data",
                    "delegate", "do", "dynamic", "else", "enum", "expect", "external", "false", "field",
                    "file", "final", "finally", "for", "fun", "get", "if", "import", "in", "infix",
                    "init", "inline", "inner", "interface", "internal", "is", "lateinit", "object",
                    "open", "operator", "out", "override", "package", "private", "protected", "public",
                    "reified", "return", "sealed", "set", "super", "suspend", "tailrec", "this",
                    "throw", "true", "try", "typealias", "val", "var", "vararg", "when", "where", "while", "null"
                ]
            )

        case .go:
            return Self.cFamily(
                keywords: [
                    "break", "case", "chan", "const", "continue", "default", "defer", "else",
                    "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map",
                    "package", "range", "return", "select", "struct", "switch", "type", "var",
                    "bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int",
                    "int8", "int16", "int32", "int64", "rune", "string", "uint", "uint8", "uint16",
                    "uint32", "uint64", "uintptr", "nil", "true", "false", "iota", "make", "new", "len", "cap"
                ]
            )

        case .rust:
            return Self.cFamily(
                keywords: [
                    "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else",
                    "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match",
                    "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct",
                    "super", "trait", "true", "type", "unsafe", "use", "where", "while", "Some",
                    "None", "Ok", "Err", "String", "Vec", "Option", "Result", "usize", "isize",
                    "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "f32", "f64", "bool", "str"
                ]
            )

        case .python:
            return LanguageSpec(
                keywords: [
                    "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del",
                    "elif", "else", "except", "False", "finally", "for", "from", "global", "if",
                    "import", "in", "is", "lambda", "None", "nonlocal", "not", "or", "pass", "raise",
                    "return", "True", "try", "while", "with", "yield", "self", "print", "len",
                    "range", "str", "int", "float", "list", "dict", "set", "tuple", "open"
                ],
                lineComment: ["#"],
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("@[A-Za-z_][A-Za-z0-9_.]*", .attribute)
                ]
            )

        case .ruby:
            return LanguageSpec(
                keywords: [
                    "alias", "and", "begin", "break", "case", "class", "def", "defined?", "do", "else",
                    "elsif", "end", "ensure", "false", "for", "if", "in", "module", "next", "nil",
                    "not", "or", "redo", "rescue", "retry", "return", "self", "super", "then", "true",
                    "undef", "unless", "until", "when", "while", "yield", "require", "puts", "attr_accessor"
                ],
                lineComment: ["#"],
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("@{1,2}[A-Za-z_][A-Za-z0-9_]*", .attribute)
                ]
            )

        case .php:
            return LanguageSpec(
                keywords: [
                    "abstract", "and", "array", "as", "break", "callable", "case", "catch", "class",
                    "clone", "const", "continue", "declare", "default", "do", "echo", "else", "elseif",
                    "empty", "enddeclare", "endfor", "endforeach", "endif", "endswitch", "endwhile",
                    "extends", "final", "finally", "fn", "for", "foreach", "function", "global", "goto",
                    "if", "implements", "include", "include_once", "instanceof", "insteadof",
                    "interface", "isset", "list", "match", "namespace", "new", "null", "or", "print",
                    "private", "protected", "public", "readonly", "require", "require_once", "return",
                    "static", "switch", "throw", "trait", "true", "false", "try", "unset", "use", "var",
                    "while", "yield", "echo"
                ],
                lineComment: ["//", "#"],
                blockComment: ("/*", "*/"),
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("\\$[A-Za-z_][A-Za-z0-9_]*", .attribute),
                    ("<\\?php|\\?>", .meta)
                ]
            )

        case .perl:
            return LanguageSpec(
                keywords: [
                    "my", "our", "sub", "if", "elsif", "else", "unless", "while", "until", "for",
                    "foreach", "last", "next", "redo", "return", "use", "package", "require", "print",
                    "die", "warn", "chomp", "split", "join", "push", "pop", "shift", "unshift",
                    "defined", "undef", "shift", "local", "scalar", "qw"
                ],
                lineComment: ["#"],
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("[$@%][A-Za-z_][A-Za-z0-9_]*", .attribute)
                ]
            )

        case .lua:
            return LanguageSpec(
                keywords: [
                    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto",
                    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
                    "until", "while", "require", "print", "pairs", "ipairs", "table", "string", "math"
                ],
                lineComment: ["--"],
                blockComment: ("--[[", "]]"),
                stringQuotes: ["\"", "'"]
            )

        case .r:
            return LanguageSpec(
                keywords: [
                    "if", "else", "repeat", "while", "function", "for", "in", "next", "break",
                    "TRUE", "FALSE", "NULL", "Inf", "NaN", "NA", "library", "require", "return",
                    "print", "c", "list", "data.frame", "factor", "matrix"
                ],
                lineComment: ["#"],
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("[A-Za-z_.][A-Za-z0-9_.]*\\s*(?=\\()", .attribute)
                ]
            )

        case .dart:
            return Self.cFamily(
                keywords: [
                    "abstract", "as", "assert", "async", "await", "break", "case", "catch", "class",
                    "const", "continue", "covariant", "default", "deferred", "do", "dynamic", "else",
                    "enum", "export", "extends", "extension", "external", "factory", "false", "final",
                    "finally", "for", "Function", "get", "hide", "if", "implements", "import", "in",
                    "interface", "is", "late", "library", "mixin", "new", "null", "on", "operator",
                    "part", "required", "rethrow", "return", "set", "show", "static", "super", "switch",
                    "sync", "this", "throw", "true", "try", "typedef", "var", "void", "while", "with", "yield"
                ]
            )

        case .scala:
            return Self.cFamily(
                keywords: [
                    "abstract", "case", "catch", "class", "def", "do", "else", "enum", "extends",
                    "false", "final", "finally", "for", "forSome", "given", "if", "implicit", "import",
                    "lazy", "match", "new", "null", "object", "override", "package", "private",
                    "protected", "return", "sealed", "super", "then", "this", "throw", "trait", "true",
                    "try", "type", "val", "var", "while", "with", "yield", "using"
                ]
            )

        case .haskell:
            return LanguageSpec(
                keywords: [
                    "case", "class", "data", "default", "deriving", "do", "else", "if", "import", "in",
                    "infix", "instance", "let", "module", "newtype", "of", "then", "type", "where",
                    "forall", "foreign", "qualified", "as", "hiding", "True", "False", "Nothing", "Just"
                ],
                lineComment: ["--"],
                blockComment: ("{-", "-}"),
                stringQuotes: ["\""],
                extraRules: [
                    ("[A-Z][A-Za-z0-9_']*", .attribute)
                ]
            )

        case .javascript:
            return Self.cFamily(
                keywords: [
                    "async", "await", "break", "case", "catch", "class", "const", "continue",
                    "debugger", "default", "delete", "do", "else", "export", "extends", "false",
                    "finally", "for", "from", "function", "get", "if", "import", "in", "instanceof",
                    "let", "new", "null", "of", "return", "set", "static", "super", "switch", "this",
                    "throw", "true", "try", "typeof", "undefined", "var", "void", "while", "with",
                    "yield", "console", "document", "window", "Array", "Object", "JSON", "Promise"
                ],
                backtick: true
            )

        case .typescript:
            return Self.cFamily(
                keywords: [
                    "abstract", "any", "as", "async", "await", "boolean", "break", "case", "catch",
                    "class", "const", "constructor", "continue", "declare", "default", "delete", "do",
                    "else", "enum", "export", "extends", "false", "finally", "for", "from", "function",
                    "get", "if", "implements", "import", "in", "infer", "instanceof", "interface",
                    "is", "keyof", "let", "namespace", "never", "new", "null", "number", "object",
                    "of", "private", "protected", "public", "readonly", "return", "set", "static",
                    "string", "super", "switch", "this", "throw", "true", "try", "type", "typeof",
                    "undefined", "unknown", "var", "void", "while", "yield"
                ],
                backtick: true
            )

        case .json:
            return LanguageSpec(
                keywords: ["true", "false", "null"],
                lineComment: [],
                stringQuotes: ["\""],
                extraRules: [
                    ("\"(?:\\\\.|[^\"\\\\])*\"(?=\\s*:)", .key)
                ]
            )

        case .xml:
            return LanguageSpec(
                keywords: [],
                lineComment: [],
                blockComment: ("<!--", "-->"),
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("</?[A-Za-z_][A-Za-z0-9_.:-]*", .tag),
                    ("/?>", .tag),
                    ("\\b[A-Za-z_][A-Za-z0-9_.:-]*(?=\\s*=)", .attribute)
                ]
            )

        case .html:
            return LanguageSpec(
                keywords: [],
                lineComment: [],
                blockComment: ("<!--", "-->"),
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("</?[A-Za-z][A-Za-z0-9-]*", .tag),
                    ("/?>", .tag),
                    ("\\b[A-Za-z-]+(?=\\s*=)", .attribute),
                    ("&[A-Za-z]+;|&#\\d+;", .meta)
                ]
            )

        case .css:
            return LanguageSpec(
                keywords: [
                    "important", "media", "import", "charset", "keyframes", "supports", "font-face"
                ],
                lineComment: [],
                blockComment: ("/*", "*/"),
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("[.#][A-Za-z_][A-Za-z0-9_-]*", .tag),
                    ("[A-Za-z-]+(?=\\s*:)", .attribute),
                    ("#[0-9a-fA-F]{3,8}\\b", .number)
                ]
            )

        case .scss:
            return LanguageSpec(
                keywords: [
                    "important", "media", "import", "mixin", "include", "extend", "if", "else",
                    "each", "for", "while", "function", "return", "use", "forward"
                ],
                lineComment: ["//"],
                blockComment: ("/*", "*/"),
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("[$@][A-Za-z_][A-Za-z0-9_-]*", .attribute),
                    ("[.#&][A-Za-z_][A-Za-z0-9_-]*", .tag),
                    ("#[0-9a-fA-F]{3,8}\\b", .number)
                ]
            )

        case .markdown:
            return LanguageSpec(
                keywords: [],
                lineComment: [],
                blockComment: nil,
                stringQuotes: ["`"],
                extraRules: [
                    ("(?m)^#{1,6}\\s.*$", .keyword),
                    ("\\*\\*[^*]+\\*\\*|__[^_]+__", .attribute),
                    ("\\[[^\\]]*\\]\\([^)]*\\)", .string),
                    ("(?m)^\\s*[-*+]\\s", .tag)
                ]
            )

        case .yaml:
            return LanguageSpec(
                keywords: ["true", "false", "null", "yes", "no", "on", "off"],
                lineComment: ["#"],
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("(?m)^\\s*-?\\s*[A-Za-z0-9_.-]+(?=\\s*:)", .attribute)
                ]
            )

        case .sql:
            return LanguageSpec(
                keywords: [
                    "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
                    "CREATE", "TABLE", "ALTER", "DROP", "INDEX", "VIEW", "JOIN", "LEFT", "RIGHT",
                    "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "OFFSET",
                    "AS", "AND", "OR", "NOT", "NULL", "IS", "IN", "LIKE", "BETWEEN", "DISTINCT",
                    "COUNT", "SUM", "AVG", "MIN", "MAX", "PRIMARY", "KEY", "FOREIGN", "REFERENCES",
                    "DEFAULT", "UNIQUE", "CASE", "WHEN", "THEN", "ELSE", "END", "UNION", "ALL",
                    "select", "from", "where", "insert", "into", "values", "update", "set", "delete"
                ],
                lineComment: ["--"],
                blockComment: ("/*", "*/"),
                stringQuotes: ["\"", "'"]
            )

        case .shell:
            return LanguageSpec(
                keywords: [
                    "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
                    "case", "esac", "function", "return", "break", "continue", "local", "export",
                    "readonly", "declare", "unset", "shift", "source", "echo", "printf", "read",
                    "exit", "set", "trap", "test", "sudo", "cd", "ls", "cp", "mv", "rm", "mkdir",
                    "cat", "grep", "sed", "awk", "curl", "wget", "git", "docker", "npm"
                ],
                lineComment: ["#"],
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("\\$\\{[^}]*\\}|\\$[A-Za-z_][A-Za-z0-9_]*|\\$[0-9@*#?$!]", .attribute)
                ]
            )

        case .dockerfile:
            return LanguageSpec(
                keywords: [
                    "FROM", "RUN", "CMD", "LABEL", "MAINTAINER", "EXPOSE", "ENV", "ADD", "COPY",
                    "ENTRYPOINT", "VOLUME", "USER", "WORKDIR", "ARG", "ONBUILD", "STOPSIGNAL",
                    "HEALTHCHECK", "SHELL", "AS"
                ],
                lineComment: ["#"],
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("(?m)^\\s*[A-Z]+(?=\\s)", .keyword)
                ]
            )

        case .makefile:
            return LanguageSpec(
                keywords: [
                    "ifeq", "ifneq", "ifdef", "ifndef", "else", "endif", "include", "define", "endef",
                    "export", "unexport", "override", "PHONY", ".PHONY"
                ],
                lineComment: ["#"],
                stringQuotes: ["\"", "'"],
                extraRules: [
                    ("(?m)^[A-Za-z0-9_./%\\-]+\\s*:(?!=)", .tag),
                    ("\\$\\([^)]*\\)|\\$[A-Za-z@<^?]", .attribute)
                ]
            )
        }
    }

    // MARK: - C 系语言共用骨架

    private static func cFamily(
        keywords: [String],
        hashRules: Bool = false,
        backtick: Bool = false
    ) -> LanguageSpec {
        var quotes: [Character] = ["\"", "'"]
        if backtick { quotes.append("`") }

        var extra: [(pattern: String, style: TokenStyle)] = []
        if hashRules {
            extra.append(("(?m)^\\s*#\\s*[a-zA-Z]+", .meta))
        }
        if backtick {
            extra.append(("\\b(?:const|let|var)\\s+[A-Za-z_$][A-Za-z0-9_$]*", .attribute))
        }

        return LanguageSpec(
            keywords: keywords,
            lineComment: ["//"],
            blockComment: ("/*", "*/"),
            stringQuotes: quotes,
            extraRules: extra
        )
    }
}

// MARK: - 语言检测

enum LanguageDetector {

    static func detect(url: URL) -> CodeLanguage {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        switch name {
        case "dockerfile", "containerfile":
            return .dockerfile
        case "makefile", "gnumakefile":
            return .makefile
        default:
            break
        }
        if name.hasPrefix("dockerfile.") { return .dockerfile }

        switch ext {
        case "swift": return .swift
        case "h", "hh", "hpp", "hxx", "h++": return .cpp
        case "c": return .c
        case "cc", "cpp", "cxx", "c++", "ino": return .cpp
        case "m", "mm": return .objectiveC
        case "cs": return .csharp
        case "java": return .java
        case "kt", "kts": return .kotlin
        case "go": return .go
        case "rs": return .rust
        case "py", "pyw", "pyi": return .python
        case "rb", "rake", "gemspec": return .ruby
        case "php": return .php
        case "pl", "pm": return .perl
        case "lua": return .lua
        case "r": return .r
        case "dart": return .dart
        case "scala", "sc": return .scala
        case "hs": return .haskell
        case "js", "jsx", "mjs", "cjs": return .javascript
        case "ts", "tsx", "mts", "cts": return .typescript
        case "json", "json5", "jsonc": return .json
        case "xml", "xsd", "xsl", "xslt", "plist", "storyboard", "xib", "svg": return .xml
        case "html", "htm", "xhtml", "shtml", "vue", "svelte": return .html
        case "css": return .css
        case "scss", "sass", "less": return .scss
        case "md", "markdown", "mdown": return .plain   // 纯文本后缀默认不高亮
        case "yml", "yaml": return .yaml
        case "sql": return .sql
        case "sh", "bash", "zsh", "fish", "ksh", "command", "zshrc", "bashrc": return .shell
        case "mk", "mak", "make": return .makefile
        default:
            // txt / log / csv / ini / conf … 都是纯文本
            return .plain
        }
    }
}

// MARK: - 语言偏好（按扩展名记住用户的选择）

final class LanguagePreference: ObservableObject {

    static let shared = LanguagePreference()

    @Published private(set) var overrides: [String: String] = [:]

    private let storageKey = "codeLanguageOverrides"

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] {
            overrides = saved
        }
    }

    func detected(for url: URL) -> CodeLanguage {
        LanguageDetector.detect(url: url)
    }

    func override(for url: URL) -> CodeLanguage? {
        guard let raw = overrides[url.pathExtension.lowercased()] else { return nil }
        return CodeLanguage(rawValue: raw)
    }

    func effective(for url: URL) -> CodeLanguage {
        override(for: url) ?? detected(for: url)
    }

    func setOverride(_ language: CodeLanguage?, for url: URL) {
        let key = url.pathExtension.lowercased()
        if let language {
            overrides[key] = language.rawValue
        } else {
            overrides.removeValue(forKey: key)
        }
        UserDefaults.standard.set(overrides, forKey: storageKey)
    }
}

// MARK: - 语言选择面板

struct LanguagePickerView: View {

    let url: URL

    @ObservedObject private var preference = LanguagePreference.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(
                        title: "自动识别（\(preference.detected(for: url).shortTitle)）",
                        selected: preference.override(for: url) == nil
                    ) {
                        preference.setOverride(nil, for: url)
                        dismiss()
                    }
                } footer: {
                    Text("按文件后缀自动判断语言；纯文本后缀默认不做语法高亮。")
                }

                Section("手动指定") {
                    ForEach(CodeLanguage.pickerList) { language in
                        row(
                            title: language.title,
                            selected: preference.override(for: url) == language
                        ) {
                            preference.setOverride(language, for: url)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("语法高亮")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func row(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.text)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
