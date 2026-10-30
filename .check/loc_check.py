"""Dictionary stand for VTK: every label the UI shows has a Russian entry.

Three sets:
  used    - every string the UI hands to Loc.txt: literals Loc.txt("...") in the
            mod's own scripts plus the labels of the tables that reach Loc.txt
            through a variable (Picker.group_label(EQUIP_GROUPS/INVENTORY_GROUPS)
            and Picker.SUBCATEGORY_ORDER);
  present - every string literal in those scripts, so a key that is produced by
            some path not listed above is still not reported stale;
  ru      - keys of the RU table in VTKLoc.gd.

MISSING = used - ru     -> the string silently stays English in game. Exit code 1.
STALE   = ru - present  -> the key has no producer left; safe to delete.

Run: py -3 .check\\loc_check.py
"""

import glob
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VTK_DIR = os.path.join(ROOT, "mods", "vostok-toolkit", "mods", "VTK")
VTK_GLOB = os.path.join(VTK_DIR, "*.gd")
LOC_FILE = os.path.join(VTK_DIR, "VTKLoc.gd")
PICKER_FILE = os.path.join(VTK_DIR, "VTKPicker.gd")

USED_RE = re.compile(r'Loc\.txt\(\s*"((?:[^"\\]|\\.)*)"\s*\)')
STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"' r"|'((?:[^'\\]|\\.)*)'")
RU_KEY_RE = re.compile(r"^\s*'((?:[^'\\]|\\.)*)'\s*:")
RU_BLOCK_RE = re.compile(r"^const RU := \{$(.*?)^\}$", re.S | re.M)
ROW_RE = re.compile(r'\[\s*"(?:[^"\\]|\\.)*"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\]')
LIST_RE = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')

# Таблицы, чьи подписи уходят в Loc.txt переменной, а не литералом.
GROUP_TABLES = ["EQUIP_GROUPS", "INVENTORY_GROUPS"]
ORDER_TABLES = ["SUBCATEGORY_ORDER"]

ESCAPES = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\"}


def unescape(s):
    out = []
    i = 0
    while i < len(s):
        ch = s[i]
        if ch == "\\" and i + 1 < len(s):
            out.append(ESCAPES.get(s[i + 1], s[i + 1]))
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def read(path):
    return io.open(path, encoding="utf-8", newline="").read()


def block(src, name):
    """Тело `const NAME := [ ... ]` с учётом вложенных скобок."""
    m = re.search(r"^const %s := \[" % re.escape(name), src, re.M)
    if not m:
        return None
    i = m.end()
    depth = 1
    while i < len(src) and depth:
        if src[i] == "[":
            depth += 1
        elif src[i] == "]":
            depth -= 1
        i += 1
    return src[m.end():i - 1]


def table_labels(src):
    """Подписи таблиц, которые UI отдаёт в Loc.txt переменной."""
    out = set()
    for name in GROUP_TABLES:
        body = block(src, name)
        if body is None:
            print("loc_check: table %s not found" % name)
            sys.exit(2)
        for m in ROW_RE.finditer(body):
            out.add(unescape(m.group(1)))
    for name in ORDER_TABLES:
        body = block(src, name)
        if body is None:
            print("loc_check: table %s not found" % name)
            sys.exit(2)
        for m in LIST_RE.finditer(body):
            raw = m.group(0)[1:-1]
            out.add(unescape(raw))
    return out


def ru_keys():
    src = read(LOC_FILE)
    m = RU_BLOCK_RE.search(src)
    if not m:
        print("loc_check: RU table not found in", LOC_FILE)
        sys.exit(2)
    keys = set()
    for line in m.group(1).splitlines():
        km = RU_KEY_RE.match(line)
        if km:
            keys.add(unescape(km.group(1)))
    return keys


def main():
    files = sorted(glob.glob(VTK_GLOB))
    used = set()
    present = set()
    for path in files:
        src = read(path)
        for m in USED_RE.finditer(src):
            used.add(unescape(m.group(1)))
        for m in STR_RE.finditer(src):
            present.add(unescape(m.group(1) if m.group(1) is not None else m.group(2)))
    used |= table_labels(read(PICKER_FILE))
    ru = ru_keys()
    missing = sorted(used - ru)
    stale = sorted(ru - present)
    print("files: %d  used: %d  present: %d  ru: %d"
          % (len(files), len(used), len(present), len(ru)))
    print("MISSING: %s" % missing)
    print("STALE: %s" % stale)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
