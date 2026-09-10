# -*- coding: utf-8 -*-
"""一次性：消费处固定色 token → 主题语义色（全面跟随口径，用户 2026-09-10 最新拍板）。

全面跟随：品牌绿族 primary/greenHouse/greenBanner/greenSignature/highlightOrange → accent，
         以及画布/状态 cream/creamDeeper/ink/slate/muted/stone/hairline/grey500/danger/success/link → 对应语义。
保留固定：white100（CTA 前景）、black12/black15 阴影、transparent、FuncColors.*、mutedGold（词根金色高亮）、
         share_image（位图）与 meteors 的 vipGoldBg。
访问器：绝大多数用 context.skin.colors；scare_coin_history 局部 skin 已是 ThemeVars 用 skin。
词边界正则避免子串误替换（cream != creamDeeper、muted != mutedGold）。
"""
import os
import re

# (token, field)，长 token 在前
TOKENS = [
    ('StarbucksCreamColors.greenSignature', 'accent'),
    ('StarbucksCreamColors.greenBanner', 'accent'),
    ('StarbucksCreamColors.greenHouse', 'accent'),
    ('AppColors.highlightOrange', 'accent'),
    ('MwColors.primary', 'accent'),
    ('MwColors.creamDeeper', 'cardBg'),
    ('MwColors.cream', 'cardBgAlt'),
    ('MwColors.ink', 'text1'),
    ('MwColors.slate', 'text2'),
    ('MwColors.muted', 'text2'),
    ('MwColors.grey500', 'text2'),
    ('MwColors.stone', 'text3'),
    ('MwColors.hairline', 'divider'),
    ('MwColors.danger', 'danger'),
    ('MwColors.success', 'success'),
    ('MwColors.link', 'accent'),
]

# 访问器：skin 已是 ThemeVars 的用 'skin'；share_image 位图整文件跳过
ACCESSOR = {
    'lib/features/scare_coin/presentation/scare_coin_history_page.dart': 'skin',
}
SKIP_FILES = {
    'lib/features/learning/presentation/share_image_service.dart',  # 分享位图固定品牌设计
}

DE_CONST = re.compile(r'\bconst (?=(?:LinearGradient|Icon|BoxShadow|Text|TextButton|OutlinedButton|'
                      r'ElevatedButton|IconButton|ShapeDecoration|BorderSide|TextStyle|RoundedRectangleBorder|InkWell)\()')


def has_dynamic(line):
    return '.colors.' in line


def add_skin_import(src):
    if 'context.skin' not in src or 'theme/skin_system.dart' in src:
        return src
    lines = src.split(chr(10))
    imports = [i for i, l in enumerate(lines) if l.startswith('import ')]
    if imports:
        lines.insert(imports[-1] + 1, "import 'package:word_app/theme/skin_system.dart';")
    return chr(10).join(lines)


changed = {}
for root in ['lib/features', 'lib/widgets']:
    for dp, _, fs in os.walk(root):
        for fn in fs:
            if not fn.endswith('.dart'):
                continue
            p = os.path.join(dp, fn)
            rel = p.replace(os.sep, '/')
            if rel in SKIP_FILES:
                continue
            acc = ACCESSOR.get(rel, 'context.skin.colors')
            src = open(p, encoding='utf-8').read()
            out = []
            n = 0
            for line in src.split(chr(10)):
                for tok, field in TOKENS:
                    pat = re.compile(r'\b' + re.escape(tok) + r'\b')
                    line, c = pat.subn('%s.%s' % (acc, field), line)
                    n += c
                if has_dynamic(line):
                    line = DE_CONST.sub('', line)
                out.append(line)
            if n == 0:
                continue
            new = add_skin_import(chr(10).join(out))
            open(p, 'w', encoding='utf-8', newline='\n').write(new)
            changed[rel] = n

for k, v in sorted(changed.items(), key=lambda x: -x[1]):
    print('%3d  %s' % (v, k))
print('TOTAL:', sum(changed.values()))
