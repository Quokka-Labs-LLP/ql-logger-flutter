import 'package:dio/dio.dart';
import 'package:ql_logger_flutter/src/model/user_config_model.dart';
import 'package:ql_logger_flutter/src/services/logger_service.dart';

class ServerLogger {
  static LoggerService loggerService = LoggerService();

  /// This function is used to init logs service
  static void initLoggerService(
      {String? userId,
      String? userName,
      required String env,
      required String apiToken,
      required String appName,
      required String url,
      List<String> maskKeys = const [],
      bool recordPermission = true,
      int durationInMin = 3}) {
    loggerService.initLogFile(
        userId: userId,
        userName: userName,
        env: env,
        apiToken: apiToken,
        appName: appName,
        url: url,
        maskKeys: maskKeys,
        recordPermission: recordPermission,
        durationInMin: durationInMin);
  }

  /// This function is used to store log into mobile directory
  static Future<void> log({required String message, LogType? logType}) async {
    await loggerService.log(message: message, logType: logType);
  }

  /// This function is used to get logs from mobile directory
  static Future<String> getLog() async {
    return await loggerService.getLogFile();
  }

  /// This function is used to upload logs from mobile directory to server
  static Future<String> uploadTodayLogs({LogType? logType}) async {
    return await loggerService.uploadTodayLogs(logType: logType);
  }

  /// This function used to get the configuration of the user.
  static UserConfig getUserConfig() {
    return loggerService.getUserConfig();
  }

  /// This function used to set the configuration of the user.
  static void setUserConfig({required UserConfig config}) {
    loggerService.setUserConfig(config: config);
  }

  /// [isInitialized] helps in checking whether the logger service is ready before performing any logging operations.
  static bool get isInitialized => loggerService.isInitialized;

  /// [logUploadingResponse] sets callbacks to handle the response and errors from the log upload API.
  static logUploadingResponse(Function(Response<dynamic> response)? response,
      {Function(dynamic)? onError}) {
    loggerService.logUploadingResponse = response;
    loggerService.onLogUploadingError = onError;
  }

  /// [onException] sets callback function to handle exceptions that occur during logging.
  static onException({Function(dynamic)? onError}) {
    loggerService.onException = onError;
  }
}

enum LogType { custom, error, user, open }
