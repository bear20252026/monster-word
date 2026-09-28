// 性能剖析 driver（配 integration_test/perf_profile_test.dart 使用）：
//   flutter drive --driver=test_driver/perf.dart --target=integration_test/perf_profile_test.dart -d windows --profile
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
