import 'package:dio/dio.dart';

import '../config.dart';

/// 统一响应结构 { code, message, data }（技术方案 §4）
class ApiResponse {
  const ApiResponse({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final dynamic data;

  bool get isOk => code == 0;

  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
        code: json['code'] as int? ?? -1,
        message: json['message'] as String? ?? '',
        data: json['data'],
      );
}

/// 业务异常（code != 0）
class ApiException implements Exception {
  const ApiException(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => 'ApiException($code, $message)';
}

/// 网络客户端：dio 封装，注入 Bearer token，统一解析 {code,message,data}
///
/// 仅在 `AppConfig.useMock == false` 时被仓库层使用。
class ApiClient {
  ApiClient._() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  late final Dio dio;
  String? _token;

  void setToken(String? token) => _token = token;

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) async {
    return _parse(() => dio.get(path, queryParameters: query));
  }

  Future<ApiResponse> post(String path, {dynamic body}) async {
    return _parse(() => dio.post(path, data: body));
  }

  Future<ApiResponse> patch(String path, {dynamic body}) async {
    return _parse(() => dio.patch(path, data: body));
  }

  Future<ApiResponse> delete(String path, {dynamic body}) async {
    return _parse(() => dio.delete(path, data: body));
  }

  /// multipart 文件上传（凭证，字段名 [field]，默认 file）
  Future<ApiResponse> upload(String path, String filePath,
      {String field = 'file'}) async {
    final form = FormData.fromMap({
      field: await MultipartFile.fromFile(filePath),
    });
    return _parse(() => dio.post(path, data: form));
  }

  Future<ApiResponse> _parse(Future<Response<dynamic>> Function() send) async {
    try {
      final res = await send();
      final json = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final parsed = ApiResponse.fromJson(json);
      if (!parsed.isOk) throw ApiException(parsed.code, parsed.message);
      return parsed;
    } on DioException catch (e) {
      throw ApiException(e.response?.statusCode ?? -1, _networkMessage(e));
    }
  }

  String _networkMessage(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      return '服务器打了个盹，稍后再试';
    }
    return '网络开小差了…检查一下再试试';
  }
}
