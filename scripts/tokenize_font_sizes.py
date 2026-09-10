# -*- coding: utf-8 -*-
"""一次性迁移脚本：把 lib/features、lib/widgets 里的
TextStyle(fontSize: N, [fontWeight: X,] [color: EXPR]) 替换为 MwTypography token。

规则（保守）：
- 只处理参数为 fontSize/fontWeight/color 三者之内的 TextStyle（顺序任意）；
- 必须带显式 color（避免把浅色 token 默认色烤进深色皮肤）；
- fontSize 必须是纯数字字面量（跳过 resp.fontScale 表达式）；
- 括号平衡扫描，不吞行尾逗号/括号。
"""
import os

SCALE = {
    12: ('micro', 'w500'),
    13: ('caption', 'w400'),
    14: ('bodySm', 'w400'),
    15: ('bodySm', 'w400'),
    16: ('bodyMd', 'w400'),
    18: ('heading5', 'w500'),
    20: ('titleLg', 'w600'),
    22: ('heading4', 'w500'),
    24: ('displaySm', 'w600'),
    28: ('heading3', 'w500'),
    32: ('stat', 'w700'),
    36: ('heading2', 'w500'),
}
WEIGHTS = {
    'FontWeight.w100': 'w100', 'FontWeight.w200': 'w200', 'FontWeight.w300': 'w300',
    'FontWeight.w400': 'w400', 'FontWeight.normal': 'w400', 'FontWeight.w500': 'w500',
    'FontWeight.w600': 'w600', 'FontWeight.bold': 'w700', 'FontWeight.w700': 'w700',
    'FontWeight.w800': 'w800', 'FontWeight.w900': 'w900',
}
BOLD = {(13, 'w600'): 'captionBold', (13, 'w700'): 'captionBold',
        (16, 'w600'): 'bodyBold', (16, 'w700'): 'bodyBold'}

BACKSLASH = chr(92)
NL = chr(10)


def find_span(src, start):
    """返回从 start 处 'TextStyle(' 开始的括号平衡区间结束下标（开区间）。"""
    i = start + len('TextStyle(')
    depth = 1
    in_str = None
    while i < len(src) and depth > 0:
        ch = src[i]
        if in_str:
            if ch == in_str and src[i - 1] != BACKSLASH:
                in_str = None
        elif ch in ("'", '"'):
            in_str = ch
        elif ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        i += 1
    return i if depth == 0 else -1


def split_args(inner):
    """按顶层逗号切分参数（括号/字符串感知）。"""
    args, buf, depth, in_str = [], [], 0, None
    i = 0
    while i < len(inner):
        ch = inner[i]
        if in_str:
            buf.append(ch)
            if ch == in_str and inner[i - 1] != BACKSLASH:
                in_str = None
        elif ch in ("'", '"'):
            in_str = ch
            buf.append(ch)
        elif ch == '(':
            depth += 1
            buf.append(ch)
        elif ch == ')':
            depth -= 1
            buf.append(ch)
        elif ch == ',' and depth == 0:
            args.append(''.join(buf).strip())
            buf = []
        else:
            buf.append(ch)
        i += 1
    if buf:
        args.append(''.join(buf).strip())
    return args


def transform(src):
    out, pos, count = [], 0, 0
    while True:
        start = src.find('TextStyle(fontSize:', pos)
        if start < 0:
            out.append(src[pos:])
            break
        end = find_span(src, start)
        if end < 0:
            out.append(src[pos:start + len('TextStyle(')])
            pos = start + len('TextStyle(')
            continue
        inner = src[start + len('TextStyle('):end - 1]
        args = split_args(inner)
        ok = bool(args) and len(args) <= 3 and all(a.startswith(('fontSize:', 'fontWeight:', 'color:')) for a in args)
        kv = {}
        if ok:
            for a in args:
                k, v = a.split(':', 1)
                kv[k.strip()] = v.strip()
            size_raw = kv.get('fontSize', '')
            ok = size_raw.isdigit() and int(size_raw) in SCALE and 'color' in kv
        if ok:
            fw = kv.get('fontWeight')
            wname = WEIGHTS.get(fw) if fw else 'w400'
            ok = fw is None or wname is not None
        if not ok:
            out.append(src[pos:end])
            pos = end
            continue
        size = int(kv['fontSize'])
        token, default_w = SCALE[size]
        token = BOLD.get((size, wname), token)
        parts = []
        if wname != default_w:
            parts.append('fontWeight: %s' % (fw or 'FontWeight.w400'))
        parts.append('color: %s' % kv['color'])
        repl = 'MwTypography.%s.copyWith(%s)' % (token, ', '.join(parts))
        out.append(src[pos:start])
        out.append(repl)
        pos = end
        count += 1
    return ''.join(out), count


changed = {}
for root in ['lib/features', 'lib/widgets']:
    for dirpath, _, files in os.walk(root):
        for fn in files:
            if not fn.endswith('.dart'):
                continue
            p = os.path.join(dirpath, fn)
            rel = p.replace(os.sep, '/')
            with open(p, encoding='utf-8') as f:
                src = f.read()
            new, n = transform(src)
            if n == 0:
                continue
            # 缺 import 的补上（放在最后一个 import 之后）；part 文件没有 import，靠父 library。
            if 'MwTypography' in new and 'tokens/design_tokens.dart' not in new:
                ls = new.split(NL)
                imports = [j for j, x in enumerate(ls) if x.startswith('import ')]
                if imports:
                    ls.insert(imports[-1] + 1, "import 'package:word_app/tokens/design_tokens.dart';")
                    new = NL.join(ls)
            with open(p, 'w', encoding='utf-8', newline='\n') as f:
                f.write(new)
            changed[rel] = n

total = sum(changed.values())
for k, v in sorted(changed.items(), key=lambda x: -x[1]):
    print('%3d  %s' % (v, k))
print('TOTAL replaced: %d' % total)
