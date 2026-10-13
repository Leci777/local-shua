import 'package:flutter/foundation.dart';

/// 日志：只在 debug 模式输出；严禁打印 token 和完整文件路径列表（架构 §8.4）。
/// release 包里这些都是空转，不产生任何输出。
void dLog(String message) {
  if (kDebugMode) {
    debugPrint('[本地刷] $message');
  }
}
