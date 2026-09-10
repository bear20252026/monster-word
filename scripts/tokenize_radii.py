# -*- coding: utf-8 -*-
"""一次性迁移脚本：BorderRadius.circular(数字) → BorderRadius.circular(context.design.radius.X)。

- 只转 DesignRadius 阶梯内的数字（6/10/14/16/20/24/28/32/9999）；
- 转换后同行的 `const BorderRadius...` 去掉 const（copyWith 非常量）；
- 无 BuildContext 的位置由 flutter analyze 暴露后手工处理。
"""
import os
import re

RADIUS = {
    '6': 'xs',
    '10': 'sm',
    '14': 'md',
    '16': 'control',
    '20': 'lg',
    '24': 'xl',
    '28': 'sheet',
    '32': 'xxl',
    '9999': 'pill',
}
PAT = re.compile(r'BorderRadius\.circular\((\d+)\)')

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

            def repl(m):
                token = RADIUS.get(m.group(1))
                if token is None:
                    return m.group(0)
                return 'BorderRadius.circular(context.design.radius.%s)' % token

            new, n = PAT.subn(repl, src)
            if n == 0:
                continue
            # 去掉紧跟其前的 const（非常量了）
            new2 = new.replace('const BorderRadius.circular(context.design.radius.',
                               'BorderRadius.circular(context.design.radius.')
            with open(p, 'w', encoding='utf-8', newline='\n') as f:
                f.write(new2)
            changed[rel] = n

total = sum(changed.values())
for k, v in sorted(changed.items(), key=lambda x: -x[1]):
    print('%3d  %s' % (v, k))
print('TOTAL replaced: %d' % total)
