"""用 tree-sitter 的 Swift 语法树做真正的语法检查。
只报语法错误（ERROR / MISSING 节点），不做类型检查。
"""
import os
import sys
from tree_sitter import Language, Parser
import tree_sitter_swift

LANG = Language(tree_sitter_swift.language())
PARSER = Parser(LANG)


def walk(node, src, out, depth=0):
    if node.type == "ERROR" or node.is_missing:
        line = node.start_point[0] + 1
        col = node.start_point[1] + 1
        text = src[node.start_byte:node.end_byte].decode("utf-8", "replace")
        snippet = text.replace("\n", " ")[:120]
        out.append((line, col, node.type, node.is_missing, snippet))
        return  # 不深入，避免刷屏
    for child in node.children:
        walk(child, src, out)


def main(root_dir):
    total = 0
    bad_files = 0
    for root, _, files in os.walk(root_dir):
        for f in sorted(files):
            if not f.endswith(".swift"):
                continue
            total += 1
            p = os.path.join(root, f)
            with open(p, "rb") as fh:
                src = fh.read()
            tree = PARSER.parse(src)
            issues = []
            walk(tree.root_node, src, issues)
            if issues:
                bad_files += 1
                print(f"\n=== {p}  ({len(issues)} issue)")
                for line, col, typ, missing, snippet in issues[:12]:
                    flag = "MISSING" if missing else typ
                    print(f"  L{line}:{col}  [{flag}]  {snippet}")
    print(f"\n解析文件 {total} 个，有语法问题的 {bad_files} 个")
    return 1 if bad_files else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "Sivan"))
