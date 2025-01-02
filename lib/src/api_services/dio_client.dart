import 'package:dio/dio.dart';

class DioClient {
  final Dio _dio = Dio();

  BaseOptions _dioOptions() {
    final BaseOptions opts = BaseOptions()
      ..connectTimeout = const Duration(seconds: 60)
      ..receiveTimeout = const Duration(seconds: 60)
      ..sendTimeout = const Duration(seconds: 60);
    return opts;
  }

  Dio provideDio() {
    _dio.options = _dioOptions();
    return _dio;
  }
}
