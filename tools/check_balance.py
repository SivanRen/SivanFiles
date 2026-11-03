import os


def strip_literals(s):
    out = []
    i = 0
    n = len(s)
    in_str = False
    esc = False
    in_block = False
    in_line = False
    while i < n:
        c = s[i]
        if in_line:
            if c == "\n":
                in_line = False
                out.append(c)
            i += 1
            continue
        if in_block:
            if c == "*" and i + 1 < n and s[i + 1] == "/":
                in_block = False
                i += 2
                continue
            if c == "\n":
                out.append(c)
            i += 1
            continue
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == "/" and i + 1 < n and s[i + 1] == "/":
            in_line = True
            i += 2
            continue
        if c == "/" and i + 1 < n and s[i + 1] == "*":
            in_block = True
            i += 2
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        # Swift 原始字符串 #"..."# / ##"..."##（正则里常有括号，跳过它们）
        if c == "#":
            j = i
            while j < n and s[j] == "#":
                j += 1
            if j < n and s[j] == '"':
                hashes = j - i
                terminator = '"' + "#" * hashes
                k = s.find(terminator, j + 1)
                if k != -1:
                    i = k + len(terminator)
                    continue
        out.append(c)
        i += 1
    return "".join(out)


bad = 0
count = 0
for root, _, files in os.walk("Sivan"):
    for f in files:
        if not f.endswith(".swift"):
            continue
        count += 1
        p = os.path.join(root, f)
        code = strip_literals(open(p, encoding="utf-8").read())
        b = code.count("{") - code.count("}")
        q = code.count("(") - code.count(")")
        k = code.count("[") - code.count("]")
        if b or q or k:
            bad += 1
            print("%s: braces %d parens %d brackets %d" % (p, b, q, k))
print("checked %d files, imbalanced %d" % (count, bad))
