import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/preferences_store.dart';
import 'router/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SharedPreferences 要先打开，再作为 override 注入（它不依赖 BuildContext）
  final prefs = await PreferencesStore.open();
  runApp(
    ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
      child: const LocalShuaApp(),
    ),
  );
}
