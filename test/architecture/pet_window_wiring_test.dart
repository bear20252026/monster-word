// 桌面宠物窗口的**跨语言接线**守卫。
//
// 这个功能最危险的失败方式不是崩溃，而是**静默失败**：
// - `lib/main.dart` 忘了 export → petMain 不进 app.so → 窗口一片空白，无报错；
// - 原生 `set_dart_entrypoint("petMain")` 与 Dart 函数名不一致 → 同上；
// - 通道名两边不一致 → 点了没反应，也不报错。
//
// 这些都编译得过、单测也全绿，只有真机上才看得出来。所以直接读源码对齐。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/infrastructure/pet_window_service.dart';
import 'package:word_app/pet_main.dart';

void main() {
  test('宠物入口必须被 main.dart export（漏了不报错，只会让窗口一片空白）', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(
      main.contains("export 'package:word_app/pet_main.dart'"),
      isTrue,
      reason: '没有任何代码调用 petMain，只有 export 出去它才会被编进 app.so',
    );
  });

  test('petMain 必须带 vm:entry-point，且原生按同名查找', () {
    final pet = File('lib/pet_main.dart').readAsStringSync();
    expect(pet.contains("@pragma('vm:entry-point')"), isTrue, reason: 'AOT 会裁掉没有该标注的入口');
    expect(pet.contains('void petMain('), isTrue);

    final native = File('windows/runner/pet_host.cpp').readAsStringSync();
    expect(native.contains('set_dart_entrypoint("petMain")'), isTrue, reason: '原生与 Dart 的入口名必须一字不差');
  });

  test('通道名两边一致（不一致的表现是点了没反应，不是报错）', () {
    final expected = PetWindowService.channel.name;
    expect(expected, isNotEmpty);

    for (final path in ['windows/runner/pet_host.cpp', 'windows/runner/flutter_window.cpp']) {
      final source = File(path).readAsStringSync();
      expect(source.contains('"$expected"'), isTrue, reason: '$path 的通道名与 Dart 不一致');
    }
    expect(petWindowChannel.name, expected, reason: '两个 Dart 入口必须用同一个通道名');
  });

  test('签到天数靠启动参数跨 engine 传递（两个 engine 不共享内存）', () {
    final native = File('windows/runner/pet_host.cpp').readAsStringSync();
    expect(native.contains('set_dart_entrypoint_arguments'), isTrue, reason: '没有它，宠物不知道自己长到第几形态');
    expect(native.contains('"days="'), isTrue);

    final pet = File('lib/pet_main.dart').readAsStringSync();
    expect(pet.contains("== 'days'"), isTrue, reason: '解析键名必须与原生拼的 days= 对得上');
  });

  test('窗口配置逐条对上 VPet 的 MainWindow.xaml', () {
    final native = File('windows/runner/pet_host.cpp').readAsStringSync();

    expect(native.contains('WS_POPUP'), isTrue, reason: 'WindowStyle="None" → 无标题栏无边框');
    expect(native.contains('WS_EX_TOOLWINDOW'), isTrue, reason: 'ShowInTaskbar="False" → 不进任务栏');
    expect(native.contains('WS_EX_TOPMOST'), isTrue, reason: 'Topmost → 盖在别的应用之上');
    expect(native.contains('DwmExtendFrameIntoClientArea'), isTrue, reason: 'GlassFrameThickness="-1" → 客户区变玻璃');
    expect(native.contains('SetWindowCompositionAttribute'), isTrue, reason: '只延伸玻璃还不够，要把它刷成全透明');
  });

  test('宠物窗口不许有 Scaffold（有一层不透明底色，桌面就透不出来）', () {
    final pet = File('lib/pet_main.dart').readAsStringSync();

    expect(pet.contains('Scaffold('), isFalse, reason: '套了 Scaffold 就是一块不透明方块，透明窗口白做');
  });
}
