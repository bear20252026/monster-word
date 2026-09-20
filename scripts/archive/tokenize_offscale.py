# -*- coding: utf-8 -*-
"""一次性：off-scale 字号/圆角字面量收敛（2026-09-10）。
只处理脱离刻度的值；on-scale 字面量保留（本身在刻度上）。
圆角用静态 AppRadius（const/无 context 安全）；字号用 MwTypography token。
"""
import os
import re

FONT_OFF = {9: 'microXs', 10: 'microXs', 11: 'micro', 15: 'bodySm',
            17: 'bodyMd', 19: 'heading5', 21: 'titleLg', 34: 'stat', 56: 'heading1'}
RADIUS_OFF = {2: 'xs', 3: 'xs', 4: 'xs', 5: 'xs', 8: 'sm', 9: 'sm',
              12: 'md', 40: 'xxl', 999: 'pill'}


def add_microXs():
    p = 'lib/tokens/design_tokens.dart'
    s = open(p, encoding='utf-8').read()
    if 'static const TextStyle microXs' in s:
        return
    anchor = '  static const TextStyle micro = TextStyle('
    block = ('  /// 徽章最小字（10/w700）——通知角标等极小数字。\n'
             '  static const TextStyle microXs = TextStyle(\n'
             '    fontSize: 10,\n'
             '    fontWeight: FontWeight.w700,\n'
             '    height: 1.1,\n'
             '    color: StarbucksCreamColors.text1,\n'
             '  );\n\n')
    assert anchor in s
    open(p, 'w', encoding='utf-8', newline='\n').write(s.replace(anchor, block + anchor, 1))
    print('added microXs token')


def add_import(s, imp):
    if imp in s:
        return s
    lines = s.split(chr(10))
    idx = [i for i, l in enumerate(lines) if l.startswith('import ')]
    if not idx:
        return s
    lines.insert(idx[-1] + 1, imp)
    return chr(10).join(lines)


def main():
    add_microXs()
    fn = rn = 0
    for root in ['lib/features', 'lib/widgets', 'lib/app']:
        for dp, _, fs in os.walk(root):
            for f in fs:
                if not f.endswith('.dart'):
                    continue
                path = os.path.join(dp, f)
                rel = path.replace(os.sep, '/')
                if rel in ('lib/app/app.dart', 'lib/features/learning/presentation/share_image_service.dart'):
                    continue
                src = open(path, encoding='utf-8').read()
                lines = src.split(chr(10))
                out = []
                fcnt = rcnt = 0
                for line in lines:
                    for v, tok in FONT_OFF.items():
                        pat = re.compile(r'fontSize:\s*%d(?=\s*[,)])' % v)
                        line, n = pat.subn('fontSize: MwTypography.%s.fontSize' % tok, line)
                        fcnt += n
                    for v, tok in RADIUS_OFF.items():
                        pat = re.compile(r'BorderRadius\.circular\(%d\)' % v)
                        line, n = pat.subn('BorderRadius.circular(AppRadius.%s)' % tok, line)
                        rcnt += n
                    if 'MwTypography.' in line:
                        line = re.sub(r'\bconst (?=TextStyle\(|Text\()', '', line)
                    out.append(line)
                new = chr(10).join(out)
                if fcnt or rcnt:
                    if 'MwTypography.' in new:
                        new = add_import(new, "import 'package:word_app/tokens/design_tokens.dart';")
                    open(path, 'w', encoding='utf-8', newline='\n').write(new)
                    fn += fcnt
                    rn += rcnt
                    print('%2d font %2d radius  %s' % (fcnt, rcnt, rel))
    print('TOTAL font:%d radius:%d' % (fn, rn))


if __name__ == '__main__':
    main()