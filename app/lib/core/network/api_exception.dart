import 'package:dio/dio.dart';

/// 统一错误类型。文案是小白口吻：出了什么事 + 大概原因 + 下一步干嘛（架构 §8.6）。
/// 所有 DioException 都在这里归一，别处在 UI 里现场编文案。
class ApiException implements Exception {
  /// 服务端错误码（如 token_invalid）；网络层错误用本地码（timeout/offline）
  final String code;
  final String message;

  const ApiException({required this.code, required this.message});

  /// 原始响应状态码，没有（网络错误）为 null
  final int? statusCode = null;

  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      // dio 5.x 新增的「转码超时」，和普通超时一个处理
      case DioExceptionType.transformTimeout:
        return const ApiException(
          code: 'timeout',
          message: '电脑半天没反应，看看网络或者电脑是不是睡着了',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          code: 'offline',
          message: '连不上电脑。挨个看看：① 电脑开机了吗？② 服务启动了吗？③ 同一个 WiFi 吗？',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          code: 'bad_certificate',
          message: '电脑那边的证书有问题',
        );
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
      case DioExceptionType.cancel:
        return const ApiException(code: 'cancelled', message: '已取消');
      case DioExceptionType.unknown:
        return const ApiException(
          code: 'unknown',
          message: '出了点意外，再试一次看看',
        );
    }
  }

  static ApiException _fromResponse(Response? response) {
    final data = response?.data;
    if (data is Map && data['code'] is String && data['message'] is String) {
      return ApiException(
        code: data['code'] as String,
        message: data['message'] as String,
      );
    }
    final status = response?.statusCode ?? 0;
    return ApiException(
      code: 'http_$status',
      message: '电脑服务回了点意外内容（$status）',
    );
  }

  @override
  String toString() => 'ApiException($code): $message';
}
