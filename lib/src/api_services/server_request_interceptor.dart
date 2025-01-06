import 'package:dio/dio.dart';
import 'package:ql_logger_flutter/ql_logger_flutter.dart';
import 'package:ql_logger_flutter/src/device_info.dart';

class ServerRequestInterceptor extends Interceptor {
  @override
  void onError(final DioException err, final ErrorInterceptorHandler handler) async {
    ServerLogger.log(
        message:
            '[${err.requestOptions.method}] ${err.requestOptions.uri}\nError Response: ${err.requestOptions.uri}\n${err.response}',
        logType: LogType.error.name);
    return super.onError(err, handler);
  }

  @override
  Future<void> onRequest(
    final RequestOptions options,
    final RequestInterceptorHandler handler,
  ) async {
    ServerLogger.log(
        message: '[${options.method}] ${options.uri}\nRequest Params: ${options.data}',
        logType: DeviceInfo.userId != null ? LogType.user.name : LogType.open.name);
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(
    final Response response,
    final ResponseInterceptorHandler handler,
  ) {
    ServerLogger.log(
        message:
            '[${response.requestOptions.method}] ${response.requestOptions..uri}\nResponse: ${response.requestOptions}\n${response.data}',
        logType: DeviceInfo.userId != null ? LogType.user.name : LogType.open.name);
    return super.onResponse(response, handler);
  }
}
