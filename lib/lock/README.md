# 锁屏学习模块 (lock)

## 概述

本模块移植自 v3.2 的 `cn.com.langeasy.LangEasyLexis.lock` 包，实现了"不背单词"的核心特色功能：**锁屏状态下显示单词供用户学习**。

## 架构

采用 MVP（Model-View-Presenter）架构：

```
┌─────────────────────────────────────────────┐
│                LockScreenPage               │
│                (Flutter Widget)              │
│                    │                        │
│         implements LockView                 │
│                    │                        │
│         ┌──────────┴──────────┐             │
│         │   LockPresenterImp  │             │
│         │   (业务逻辑层)       │             │
│         └──────────┬──────────┘             │
│                    │                        │
│    ┌───────────────┼───────────────┐        │
│    │               │               │        │
│ LockService    LockMedia     本地数据库     │
│ (Platform Ch.)  (音频播放)    (单词数据)     │
└─────────────────────────────────────────────┘
```

## 文件清单

| 文件 | 来源 | 说明 |
|------|------|------|
| `lock.dart` | - | barrel 文件，统一导出 |
| `lock_presenter.dart` | LockPresenter.java | Presenter 接口 |
| `lock_presenter_imp.dart` | LockPresenterImp.java | Presenter 实现 |
| `lock_view.dart` | LockView.java | View 接口 |
| `lock_screen_page.dart` | LockViewProcessorImp.java | 锁屏主界面 |
| `lock_service.dart` | ActivityTaskService.java | Platform Channel 服务 |
| `lock_media.dart` | - | 音频播放管理 |
| `lock_webview_cache.dart` | LockWebViewCache.java | WebView 缓存 |
| `date_time_constants.dart` | DateTimeConstants.java | 日期时间常量 |
| `number_utils.dart` | NumberUtils.java | 数字工具 |
| `view_dimens.dart` | ViewDimens.java | 视图尺寸计算 |
| `spring_interpolator.dart` | SpringInterpolator.java | 弹簧动画插值器 |
| `my_element_animator.dart` | MyElementAnimator.java | 元素动画控制器 |
| `view/scroll_top_bottom_layout.dart` | ScrollTopBottomLayout.java | 上下滚动布局 |
| `view/line_indicator.dart` | LineIndicator.java | 线性指示器 |
| `view/down_callback.dart` | DownCallback.java | 下拉回调接口 |

## 使用方式

### 1. 显示锁屏

```dart
import 'package:word_app/lock/lock.dart';

// 作为独立页面显示
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const LockScreenPage(),
));
```

### 2. 监听锁屏事件

```dart
LockService.lockEventStream.listen((event) {
  switch (event['type']) {
    case 'screenOn':
      // 屏幕点亮
      break;
    case 'unlock':
      // 用户解锁
      break;
  }
});
```

### 3. 控制音频播放

```dart
final media = LockMedia();
media.needPlay = true;
await media.playWord('hello');
```

## Platform Channel 接口

需要在 Android 原生端实现以下 MethodChannel：

```kotlin
// MainActivity.kt 或专用 Plugin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.com.langeasy.lock/service")
  .setMethodCallHandler { call, result ->
    when (call.method) {
      "showLockScreen" -> { /* 显示锁屏 */ }
      "closeLockScreen" -> { /* 关闭锁屏 */ }
      "unlock" -> { /* 解锁 */ }
      "playWordAudio" -> { /* 播放单词发音 */ }
      "playSentenceAudio" -> { /* 播放例句音频 */ }
      "pauseAudio" -> { /* 暂停音频 */ }
      "getBatteryInfo" -> { /* 获取电池信息 */ }
      "getBringTaskId" -> { /* 获取前台任务 ID */ }
      else -> result.notImplemented()
    }
  }
```

## 待完成功能

- [ ] Platform Channel Android 原生实现
- [ ] 背景图片加载（从本地资源/网络）
- [ ] 单词数据源接入（LeitnerCard）
- [ ] 音频播放接入（PhoneticAudioPlayer / SentenceAudioPlayer）
- [ ] 用户偏好设置读取
- [ ] 例句 HTML 解析和渲染
- [ ] 统计事件上报
- [ ] 解锁动画优化
