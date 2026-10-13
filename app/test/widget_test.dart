// 这里原本是 flutter create 生成的样板测试（引用了本项目从来没有的 MyApp）。
// 当前依赖里 flutter_test 已经去掉、package_config 里也解析不到，
// 留着这份文件会让 flutter analyze / flutter test 直接报错，所以清空。
//
// TODO(W5-01): 想补测试的话，先把 flutter_test 加回 dev_dependencies：
//   dev_dependencies:
//     flutter_test:
//       sdk: flutter
// 然后在这里写真用例（洗牌袋不重复、进度换算、ApiException 归一）。
library;

void main() {
  // 暂无测试
}