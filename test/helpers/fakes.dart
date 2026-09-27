// 测试共享假实现（审计提升点 I64：此前 no-op AudioService 在 4+ 个测试
// 文件逐字重复）。仅放"零行为"通用假件；带记录/阻塞逻辑的变体属于被测
// 行为的一部分，留在各自测试文件内。
import 'package:word_app/core/audio/audio_service.dart';

/// 全 no-op 音频服务：吞掉所有播放调用，供页面冒烟/回归测试装配。
class NoopAudioService implements AudioService {
  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {}
  @override
  Future<void> playFromUrl(String url) async {}
  @override
  Future<void> stop() async {}
  @override
  bool get isPlaying => false;
  @override
  void dispose() {}
}
