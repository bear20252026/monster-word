#!/usr/bin/env python3
"""校验 APK 是否由**指定的发布证书**签名（只依赖标准库）。

为什么重写（2026-10-15 审计 R3-E06）：
原版只扫 `APK Sig Block 42` 魔数与两个 scheme ID 就打印
"APK IS PROPERLY SIGNED"，而且 `main()` 从不返回非 0、**完全不看签名者证书** ——
debug 签名同样「通过」。它还没有被任何 workflow 引用，所以发版链里实际上
**不存在**「产物确由 release keystore 签名」的独立校验。

本版做三件事：
  1. 从 v2（或 v3）签名块里取出**签名者证书的 DER**；
  2. 算它的 SHA-256（与 `apksigner verify --print-certs` 打印的
     "certificate SHA-256 digest" 同口径）；
  3. 与期望指纹比对，不一致或取不到证书就 **exit 1**。

用法：
    python3 check_apk_signature.py <apk> [--expect <sha256>] [--print]

期望指纹来源（按优先级）：`--expect` > 环境变量 `EXPECTED_CERT_SHA256` > 下方常量。
默认常量是 monster-word 的发布证书指纹，取自仓库备份的
`monster-word-secrets/monster-word-release.jks`
（`keytool -list -v` 的 SHA256），与 v2.13.0+129 发布包实测一致。
轮换密钥库时必须同步改这里，否则发版链会（**故意**）红。
"""

import argparse
import hashlib
import struct
import sys

# 发布证书指纹（小写十六进制，无分隔符）。见模块文档。
DEFAULT_EXPECTED = '96da5ec767c71bcca822bd7ecab91aff8c06029d8d4a7a051f04ced754c90b7e'

MAGIC = b'APK Sig Block 42'
# v2 / v3 scheme ID → 该块 value 里 signer 序列的结构差异（v3 多一层 minSdk/maxSdk）
SCHEME_V2 = 0x7109871A
SCHEME_V3 = 0xF05368C0


class ApkFormatError(Exception):
    pass


def _u32(buf, off):
    if off + 4 > len(buf):
        raise ApkFormatError('读取 uint32 越界')
    return struct.unpack_from('<I', buf, off)[0], off + 4


def _u64(buf, off):
    if off + 8 > len(buf):
        raise ApkFormatError('读取 uint64 越界')
    return struct.unpack_from('<Q', buf, off)[0], off + 8


def _length_prefixed(buf, off):
    """读一个 uint32 长度前缀，返回 (切片, 新偏移)。"""
    n, off = _u32(buf, off)
    if off + n > len(buf):
        raise ApkFormatError('长度前缀越界')
    return buf[off:off + n], off + n


def find_signing_block(data):
    """返回签名块的 pairs 区域（去掉首尾两个 uint64 长度与尾部魔数）。

    块布局（见 source.android.com 的 APK Signature Scheme v2）：
        [uint64 S][ID-value pairs][uint64 S][magic 16B]
    其中 S 是「**不含**第一个 S 字段本身」的字节数，即 S = len(pairs) + 8 + 16。
    ⇒ 第一个 S 字段的偏移 = magic偏移 - S + 8（不是 - S - 8，这里一开始算错过）。
    """
    pos = data.rfind(MAGIC)
    if pos < 0:
        raise ApkFormatError('找不到 APK Signing Block（APK 未做 v2/v3 签名）')
    size2, _ = _u64(data, pos - 8)
    block_start = pos - size2 + 8
    if block_start < 0:
        raise ApkFormatError('签名块起始位置为负，结构不符')
    size1, _ = _u64(data, block_start)
    if size1 != size2:
        raise ApkFormatError(f'签名块首尾长度不一致（{size1} != {size2}）')
    # pairs 区域：block_start+8 .. pos-8
    return data[block_start + 8:pos - 8]


def find_scheme_value(pairs, scheme_id):
    off = 0
    while off < len(pairs):
        length, off = _u64(pairs, off)
        if length < 4 or off + length > len(pairs):
            raise ApkFormatError('签名块 pair 长度越界')
        pair_id, _ = _u32(pairs, off)
        if pair_id == scheme_id:
            return pairs[off + 4:off + length]
        off += length
    return None


def first_certificate(value):
    """从 scheme 块的 value 里取出第一个签名者的证书 DER。"""
    # value = signers（长度前缀序列）
    signers, _ = _length_prefixed(value, 0)
    # 第一个 signer
    signer, _ = _length_prefixed(signers, 0)
    # signer = signed_data（长度前缀）+ signatures + public_key
    signed_data, _ = _length_prefixed(signer, 0)
    # signed_data = digests（长度前缀）+ certificates（长度前缀）+ additional_attrs
    _digests, off = _length_prefixed(signed_data, 0)
    certificates, _ = _length_prefixed(signed_data, off)
    # certificates = 长度前缀序列，第一个就是签名者证书
    cert, _ = _length_prefixed(certificates, 0)
    if not cert:
        raise ApkFormatError('证书为空')
    return cert


def cert_sha256(cert_der):
    return hashlib.sha256(cert_der).hexdigest()


def main():
    ap = argparse.ArgumentParser(description='校验 APK 是否由指定证书签名')
    ap.add_argument('apk', help='APK 路径')
    ap.add_argument('--expect', default=None, help='期望的证书 SHA-256（覆盖环境变量与默认常量）')
    ap.add_argument('--print', dest='do_print', action='store_true', help='只打印实际指纹，不比对')
    args = ap.parse_args()

    import os
    expected = (args.expect or os.environ.get('EXPECTED_CERT_SHA256') or DEFAULT_EXPECTED).strip().lower()

    with open(args.apk, 'rb') as f:
        data = f.read()
    print(f'APK: {args.apk}  ({len(data) / 1024 / 1024:.1f} MiB)')

    try:
        pairs = find_signing_block(data)
    except ApkFormatError as e:
        print(f'❌ {e}')
        print('   ⇒ 这个 APK 没有 v2/v3 签名，绝不能被当作正式包分发。')
        return 1

    schemes = []
    for name, sid in (('V2', SCHEME_V2), ('V3', SCHEME_V3)):
        value = find_scheme_value(pairs, sid)
        if value is None:
            continue
        try:
            actual = cert_sha256(first_certificate(value))
        except ApkFormatError as e:
            print(f'⚠️  {name} 块存在但解析证书失败：{e}')
            continue
        schemes.append(name)
        print(f'{name} 签名证书 SHA-256: {actual}')
        if args.do_print:
            continue
        if actual != expected:
            print('❌ 签名证书与期望不符')
            print(f'   期望: {expected}')
            print(f'   实际: {actual}')
            print('   ⇒ 产物不是用发布密钥库签的，用户将无法覆盖安装。')
            return 1

    if not schemes:
        print('❌ 没有解析出任何 v2/v3 签名证书')
        return 1

    if args.do_print:
        print(f'（--print 模式，未比对；期望值 {expected}）')
        return 0

    print(f'✅ 签名校验通过（{", ".join(schemes)}；证书指纹与发布密钥库一致）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
