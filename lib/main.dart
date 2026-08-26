import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/app_bootstrap.dart';

Future<void> main() async {
  await bootstrapApp();
  runApp(const WordApp());
}
