# -*- coding: utf-8 -*-
"""Monster Word 离线音效合成器（蓝图 W3「声音设计」）。

纯 Python 标准库生成 22050Hz/16bit/单声道 WAV，零下载零版权。
8-bit 游戏机审美：方波/三角波 + 快速衰减包络，短促不粘耳。

用法：python scripts/generate_sfx.py
输出：assets/sfx/{ui,quiz,celebrate,monster}/*.wav（总预算 <=1MB）
幂等可复现（无随机源），CI 可校验。
"""
import math
import struct
import wave
from pathlib import Path

SR = 22050
ROOT = Path(__file__).resolve().parent.parent / "assets" / "sfx"


def env(i, n, attack=0.005, release=0.6):
    """快攻慢释包络：attack 秒起音，之后线性衰减到 release 比例。"""
    t = i / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = 1.0 - (i / n) * (1.0 - release)
    return a * r


def square(freq, i, n, duty=0.5, gain=0.5):
    t = (freq * i / SR) % 1.0
    return (gain if t < duty else -gain) * env(i, n)


def tri(freq, i, n, gain=0.5):
    t = (freq * i / SR) % 1.0
    v = 4 * abs(t - 0.5) - 1
    return v * gain * env(i, n)


def noise(i, n, gain=0.3, seed=7):
    x = (i * 1103515245 + seed * 12345) & 0x7FFFFFFF
    v = ((x >> 16) / 32768.0) - 1.0
    return v * gain * env(i, n)


def sweep(f0, f1, i, n, wave_fn=square, gain=0.5):
    freq = f0 + (f1 - f0) * (i / n)
    return wave_fn(freq, i, n, gain=gain)


def write(name, samples):
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        w.writeframes(frames)
    kb = path.stat().st_size / 1024
    print(f"{name:36s} {len(samples) / SR * 1000:6.0f}ms {kb:6.1f}KB")


def seconds(sec):
    return int(SR * sec)


def main():
    # ── ui/ ──
    # 选项点选：极短嗒（1200Hz 三角波 40ms）。
    write("ui/tap.wav", [tri(1200, i, seconds(0.04), gain=0.35) for i in range(seconds(0.04))])
    # 静音键切换：两音下行确认（880→660）。
    samples = [square(880, i, seconds(0.05)) for i in range(seconds(0.05))]
    samples += [square(660, i, seconds(0.07)) for i in range(seconds(0.07))]
    write("ui/toggle.wav", samples)

    # ── quiz/ 答对音高爬升（C5 五声音阶：C5 D5 E5 G5，≥4 循环最高档）──
    notes = {"c5": 523.25, "d5": 587.33, "e5": 659.25, "g5": 783.99}
    for name, freq in notes.items():
        # 答对音：主音方波 + 八度上方三角波点缀，120ms。
        n = seconds(0.12)
        samples = [square(freq, i, n, gain=0.42) + tri(freq * 2, i, n, gain=0.18) for i in range(n)]
        write(f"quiz/correct_{name}.wav", samples)
    # 答错：低频 woop 下扫（300→180Hz 方波 160ms），轻不刺耳。
    write("quiz/wrong_soft.wav", [sweep(300, 180, i, seconds(0.16), gain=0.35) for i in range(seconds(0.16))])
    # 金币入账 tick（1568Hz 短叮 60ms，音量低）。
    write("quiz/coin_tick.wav", [tri(1568, i, seconds(0.06), gain=0.25) for i in range(seconds(0.06))])
    # 断连「噗」（180Hz 方波 90ms 低音）。
    write("quiz/combo_break.wav", [square(180, i, seconds(0.09), gain=0.3) for i in range(seconds(0.09))])

    # ── celebrate/ ──
    # 里程碑 jingle：C5-E5-G5-C6 上行琶音（各 90ms + 尾音 200ms）。
    seq = [523.25, 659.25, 783.99, 1046.5]
    samples = []
    for f in seq:
        samples += [square(f, i, seconds(0.09), gain=0.4) for i in range(seconds(0.09))]
    samples += [square(1046.5, i, seconds(0.2), gain=0.3) + tri(2093, i, seconds(0.2), gain=0.12) for i in range(seconds(0.2))]
    write("celebrate/milestone.wav", samples)
    # 进化三渐强心跳（低频 thump ×3，间隔渐密、幅度渐强）。
    samples = []
    for k, (gap, amp) in enumerate([(0.35, 0.3), (0.3, 0.45), (0.25, 0.6)]):
        thump = [sweep(120, 60, i, seconds(0.12), gain=amp) for i in range(seconds(0.12))]
        samples += thump + [0.0] * seconds(gap - 0.12)
    write("celebrate/evolve.wav", samples)

    # ── monster/ ──
    # 敲蛋壳（叩击：短噪声 + 200Hz 点）。
    n = seconds(0.06)
    samples = [noise(i, n, gain=0.3) + square(200, i, n, gain=0.25) for i in range(n)]
    write("monster/egg_knock.wav", samples)
    # 破壳闪光（噪声爆 + 上扫 400→900）。
    n = seconds(0.25)
    samples = [noise(i, n, gain=0.18, seed=11) + sweep(400, 900, i, n, gain=0.32) for i in range(n)]
    write("monster/hatch_flash.wav", samples)
    # 打嗝（下扫 250→90 方波 140ms，憨感）。
    write("monster/burp.wav", [sweep(250, 90, i, seconds(0.14), gain=0.38) for i in range(seconds(0.14))])
    # 咕噜声（被摸开心，W4.5）：低频 72→58Hz 正弦 + 24Hz 颤幅（猫呼噜的
    # rumble 质感），420ms；纯正弦比方波更「喉咙振动」。
    n = seconds(0.42)
    samples = []
    for i in range(n):
        t = i / SR
        freq = 72.0 + (58.0 - 72.0) * (i / n)
        tremolo = 0.55 + 0.45 * math.sin(2 * math.pi * 24.0 * t)
        samples.append(math.sin(2 * math.pi * freq * t) * tremolo * env(i, n, release=0.35) * 0.5)
    write("monster/purr.wav", samples)

    total = sum(f.stat().st_size for f in ROOT.rglob("*.wav"))
    print(f"total: {total / 1024:.1f}KB（预算 1024KB）")


if __name__ == "__main__":
    main()
