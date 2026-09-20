import 'package:word_app/core/infrastructure/app_preferences.dart';

/// 登出时的安全清理入口（presentation 不得直触 SecureTokenStorage/infrastructure）。
void clearSessionSecrets() {
  SecureTokenStorage().clearAll().catchError((_) {});
}
