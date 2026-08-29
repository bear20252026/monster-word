import os, re, sys

ROOT = os.getcwd()
LIB = os.path.join(ROOT, 'lib')
TEST = os.path.join(ROOT, 'test')
PKG = 'package:word_app/'

RE = re.compile(r"^(?P<indent>\s*)(?P<kw>import|export|part)\s+(?P<q>['\"])(?P<path>[^'\"]+\.dart)(?P=q)(?P<rest>.*)$")

def norm_rel(path):
    parts = []
    for seg in path.split('/'):
        if seg in ('', '.'):
            continue
        elif seg == '..':
            if parts: parts.pop()
        else:
            parts.append(seg)
    return '/'.join(parts)

DRY = '--apply' not in sys.argv
converted = 0
kept = 0
stats = {}
samples = []
kept_dest = {}

for base in (LIB, TEST):
    for dp, _, fns in os.walk(base):
        for fn in fns:
            if not fn.endswith('.dart'):
                continue
            full = os.path.join(dp, fn)
            with open(full, encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
            new_lines = []
            changed = False
            for line in lines:
                m = RE.match(line.rstrip('\n'))
                if m and not m.group('path').startswith(('package:', 'dart:')):
                    path = m.group('path')
                    kw = m.group('kw')
                    # Leave part URIs (same-lib) as-is; convert any other relative import/export
                    if kw == 'part':
                        new_lines.append(line)
                        continue
                    srcdir = os.path.dirname(full).replace('\\','/')
                    joined = os.path.normpath(os.path.join(srcdir, path)).replace('\\','/')
                    rel_from_root = os.path.relpath(joined, ROOT).replace('\\','/')
                    if joined.startswith(LIB.replace('\\','/')):
                        librel = os.path.relpath(joined, LIB).replace('\\','/')
                        librel = norm_rel(librel)
                        newpath = PKG + librel
                        newline = f"{m.group('indent')}{m.group('kw')} '{newpath}'{m.group('rest')}\n"
                        new_lines.append(newline)
                        converted += 1
                        key = os.path.relpath(full, ROOT).replace('\\','/')
                        stats[key] = stats.get(key, 0) + 1
                        if len(samples) < 8:
                            samples.append(f"{os.path.relpath(full, ROOT)}: {path} -> {newpath}")
                        changed = True
                    else:
                        new_lines.append(line)
                        kept += 1
                        krel = os.path.relpath(joined, ROOT).replace('\\','/')
                        kept_dest[krel] = kept_dest.get(krel, 0) + 1
                else:
                    new_lines.append(line)
            if changed and not DRY:
                with open(full, 'w', encoding='utf-8', errors='ignore', newline='') as f:
                    f.writelines(new_lines)

print("DRY-RUN" if DRY else "APPLIED")
print("converted (relative -> package:):", converted)
print("kept relative (test-internal/other):", kept)
print("files touched:", len(stats))
print("sample conversions:")
for s in samples:
    print("  ", s)
print("kept relative destinations (should all be test/):")
for k, v in sorted(kept_dest.items()):
    marker = "  <-- !! outside test" if not k.startswith('test') else ""
    print(f"  {k} x{v}{marker}")
