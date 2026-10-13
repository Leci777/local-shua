import '../models/folder.dart';
import '../network/api_client.dart';

/// 文件夹仓库。启停两端可改，增删只在电脑 Web 页（架构 §4.5 差异 5）。
class FolderRepository {
  const FolderRepository(this._api);

  final ApiClient _api;

  Future<List<Folder>> list() => _api.getFolders();

  Future<void> setEnabled(int folderId, bool enabled) =>
      _api.setFolderEnabled(folderId, enabled);
}
