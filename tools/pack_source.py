import os
import zipfile

ROOT = os.path.abspath("Sivan")
OUT = os.path.abspath("Sivan-source.zip")
SKIP_DIRS = {"assets-src", "build", "out", "__pycache__", ".git"}
SKIP_FILES = {".DS_Store"}

if os.path.exists(OUT):
    os.remove(OUT)

count = 0
with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as zf:
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f in SKIP_FILES:
                continue
            full = os.path.join(base, f)
            rel = os.path.relpath(full, os.path.dirname(ROOT))
            zf.write(full, rel)
            count += 1

print("files:", count, "size:", round(os.path.getsize(OUT) / 1024 / 1024, 2), "MB")
