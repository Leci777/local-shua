import 'package:dio/dio.dart';

import '../constants.dart';
import '../logger.dart';
import '../models/app_settings.dart';
import '../models/download_task.dart';
import '../models/folder.dart';
import '../models/playback_progress.dart';
import '../models/server_info.dart';
import '../models/video.dart';
import '../storage/preferences_store.dart';
import 'api_exception.dart';

/// 唯一的 HTTP 客户端。所有端点调用集中在这里，仓库层不再直接碰 dio。
/// 鉴权头、错误归一都在这一个地方（架构 §3.8）。
class ApiClient {
  ApiClient(this._prefs) {
    _dio = Dio(BaseOptions(
      connectTimeout: Constants.connectTimeout,
      receiveTimeout: Constants.receiveTimeout,
      // 返回原文，自己解——错误响应也要能读到 {code, message}
      responseType: ResponseType.json,
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _prefs.token;
        if (token != null && token.isNotEmpty) {
          options.headers['X-Api-Token'] = token;
        }
        handler.next(options);
      },
      onError: (e, handler) {
        dLog('请求失败：${e.requestOptions.path} → ${e.type}');
        handler.next(e);
      },
    ));
  }

  final PreferencesStore _prefs;
  late final Dio _dio;

  /// 配对成功后调用一次。之后所有请求都打这个 baseUrl。
  void setBaseUrl(String baseUrl) {
    // baseUrl 形如 http://192.168.1.23:57821，而请求路径一律以 /api 开头，
    // dio 是拿「主机 + 路径」重新拼的，所以这里不用补结尾斜杠
    _dio.options.baseUrl = baseUrl;
  }

  bool get hasBaseUrl => _prefs.baseUrl != null && _prefs.baseUrl!.isNotEmpty;

  // ===== 配对与服务器信息 =====

  Future<ServerInfo> getServerInfo() async {
    final data = await _get('/api/server/info');
    return ServerInfo.fromJson(data);
  }

  /// 配对换 token。成功返回 token 明文（只此一次）。
  Future<String> pair(String code, String deviceName) async {
    final data = await _post('/api/pair', {
      'code': code,
      'deviceName': deviceName,
    });
    return data['token'] as String;
  }

  // ===== 文件夹 =====

  Future<List<Folder>> getFolders() async {
    final list = (await _getList('/api/folders')).cast<Map<String, dynamic>>();
    return list.map(Folder.fromJson).toList();
  }

  Future<void> setFolderEnabled(int folderId, bool enabled) async {
    await _put('/api/folders/$folderId/enabled', {'enabled': enabled});
  }

  // ===== 视频 =====

  Future<List<Video>> getVideos({int limit = 20, String? cursor, int? folderId}) async {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    if (folderId != null) query['folderId'] = folderId;
    final data = await _get('/api/videos', query: query);
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Video.fromJson).toList();
  }

  /// 随机一袋。folderIds 为空 = 全部启用文件夹。返回视频和池大小
  /// （池太小客户端要退化成全量循环洗牌）。
  Future<({List<Video> items, int poolSize})> getRandomVideos({
    int limit = Constants.randomBatchSize,
    List<int> folderIds = const [],
    List<int> exclude = const [],
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (folderIds.isNotEmpty) query['folderIds'] = folderIds.join(',');
    if (exclude.isNotEmpty) query['exclude'] = exclude.join(',');
    final data = await _get('/api/videos/random', query: query);
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return (
      items: items.map(Video.fromJson).toList(),
      poolSize: data['poolSize'] as int? ?? items.length,
    );
  }

  /// 流式播放/下载地址（GET，带 Range）。media_kit 和 dio 下载都用它。
  String streamUrl(int videoId) {
    final base = _prefs.baseUrl!;
    return '$base/api/videos/$videoId/stream';
  }

  // ===== 进度与历史 =====

  Future<PlaybackProgress> getProgress(int videoId) async {
    final data = await _get('/api/videos/$videoId/progress');
    return PlaybackProgress.fromJson(data);
  }

  Future<void> putProgress(
    int videoId, {
    required double positionSec,
    required double durationSec,
    bool? completed,
  }) async {
    await _put('/api/videos/$videoId/progress', {
      'positionSec': positionSec,
      'durationSec': durationSec,
      if (completed != null) 'completed': completed,
    });
  }

  Future<List<({Video video, PlaybackProgress progress, String lastPlayedAt})>> getHistory({
    int limit = 50,
    String? cursor,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    final data = await _get('/api/history', query: query);
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map((e) => (
          video: Video.fromJson(e['video'] as Map<String, dynamic>),
          progress: PlaybackProgress.fromJson(e),
          lastPlayedAt: e['lastPlayedAt'] as String? ?? '',
        )).toList();
  }

  Future<void> deleteHistoryItem(int videoId) async {
    await _delete('/api/history/$videoId');
  }

  Future<void> clearHistory() async {
    await _delete('/api/history');
  }

  // ===== 收藏 =====

  Future<void> setFavorite(int videoId, bool isFavorite) async {
    await _put('/api/videos/$videoId/favorite', {'isFavorite': isFavorite});
  }

  Future<List<({Video video, String favoritedAt})>> getFavorites({
    int limit = 50,
    String? cursor,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    final data = await _get('/api/favorites', query: query);
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items
        .map((e) => (
              video: Video.fromJson(e['video'] as Map<String, dynamic>),
              favoritedAt: e['favoritedAt'] as String? ?? '',
            ))
        .toList();
  }

  // ===== 设置 =====

  Future<AppSettings> getSettings() async {
    final data = await _get('/api/settings');
    return AppSettings.fromJson(data);
  }

  Future<AppSettings> putSettings(AppSettings settings) async {
    final data = await _put('/api/settings', settings.toPatch());
    return AppSettings.fromJson(data);
  }

  // ===== 下载用的裸请求（不走 JSON 解包）=====

  Dio get dio => _dio;

  // ===== 内部：统一的请求/错误处理 =====

  Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? query}) async {
    final response = await _call(() => _dio.get(path, queryParameters: query));
    return _asMap(response.data);
  }

  Future<List<dynamic>> _getList(String path) async {
    final response = await _call(() => _dio.get(path));
    final data = response.data;
    if (data is List) return data;
    throw const ApiException(code: 'bad_response', message: '电脑回了点意外内容');
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await _call(() => _dio.post(path, data: body));
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final response = await _call(() => _dio.put(path, data: body));
    return _asMap(response.data);
  }

  Future<void> _delete(String path) async {
    await _call(() => _dio.delete(path));
  }

  /// 所有请求的统一出口：DioException → ApiException
  Future<Response<dynamic>> _call(Future<Response<dynamic>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const ApiException(code: 'bad_response', message: '电脑回了点意外内容');
  }
}
