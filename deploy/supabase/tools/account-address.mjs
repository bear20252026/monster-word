#!/usr/bin/env node
// 用户名 → 服务端账号地址（与客户端 SupabaseAccountAuthenticator.accountAddress 同算法）。
//
// 为什么需要这个脚本：服务端存的不是用户名，而是
//   u<SHA-256(归一化用户名) 前 24 位十六进制>@monster-word.internal
// 这个地址在数据库里认不出是谁。管理员要重置某人密码、或排查账号问题时，
// 先用本脚本把用户名换成地址，再去库里/管理接口里找。
//
// 算法（必须与 Dart 侧一字不差，否则管理员会找不到人）：
//   归一化 = username.trim().toLowerCase()        ← 与 SecurePasswordAuthStore 同口径
//   摘要   = SHA-256(UTF-8(归一化))
//   地址   = "u" + 摘要前 24 位十六进制 + "@" + 域名
//
// 用法：
//   node account-address.mjs alice
//   node account-address.mjs 张三 bob "a b c"
//   node account-address.mjs --list   # 打印一组自检向量（用于与客户端比对）
//
// ⚠️ 已知边界：`toLowerCase()` 在个别 Unicode 字符上 Dart 与 JS 可能有差异
//    （如土耳其语 İ）。中文、ASCII、常见符号均一致。以客户端 Dart 实现为权威——
//    如需 100% 确认，用 --list 的输出与客户端算出的值比对。

import { createHash } from 'node:crypto';

/** 与 Dart 侧 defaultEmailDomain 保持一致。 */
export const DEFAULT_DOMAIN = 'monster-word.internal';

export function accountAddress(username, domain = DEFAULT_DOMAIN) {
  const normalized = username.trim().toLowerCase();
  const digest = createHash('sha256').update(normalized, 'utf8').digest('hex');
  return `u${digest.slice(0, 24)}@${domain}`;
}

/** 自检向量：这些值来自客户端 Dart 实现的实际输出。改动算法会让它们全部不匹配。 */
const VECTORS = [
  ['alice', 'u2bd806c97f0e00af1a1fc332@monster-word.internal'],
  ['ALICE', 'u2bd806c97f0e00af1a1fc332@monster-word.internal'],
  ['  alice  ', 'u2bd806c97f0e00af1a1fc332@monster-word.internal'],
  ['小明同学', 'ubcb8839da3c394e534b231d9@monster-word.internal'],
  ['a b c', 'u0e9f64031fcb2bc708b531c2@monster-word.internal'],
  ['a@b', 'u7508d8b5018ea640b8526986@monster-word.internal'],
  ['emoji🙂', 'u0a86953ae5e56d6ce5acc30a@monster-word.internal'],
  ['bob', 'u81b637d8fcd2c6da6359e696@monster-word.internal'],
];

function runSelfCheck() {
  let failed = 0;
  for (const [name, expected] of VECTORS) {
    const actual = accountAddress(name);
    const ok = actual === expected;
    if (!ok) failed++;
    console.log(`${ok ? 'ok  ' : 'FAIL'}  ${JSON.stringify(name)} → ${actual}${ok ? '' : `  (期望 ${expected})`}`);
  }
  if (failed > 0) {
    console.error(`\n${failed} 个自检向量不匹配：本脚本与客户端算法已不一致，不要用它去查账号。`);
    process.exit(1);
  }
  console.log('\n全部匹配：本脚本与客户端 Dart 实现算法一致。');
}

const args = process.argv.slice(2);

if (args.includes('--list')) {
  runSelfCheck();
} else if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
  console.log('用法: node account-address.mjs <用户名> [更多用户名...]');
  console.log('      node account-address.mjs --list    # 自检：与客户端算法比对');
  process.exit(args.length === 0 ? 1 : 0);
} else {
  for (const name of args) {
    console.log(`${name}\t${accountAddress(name)}`);
  }
}
