import 'package:ql_logger_flutter/src/model/user_config_model.dart';
import 'package:ql_logger_flutter/src/services/logger_service.dart';

class ServerLogger {
  static LoggerService loggerService = LoggerService();

  /// This function is used to init logs service
  static Future<void> initLoggerService(
      {String? userId,
      String? userName,
      required String env,
      required String apiKey,
      required String appName,
      required String url,
      List<String> maskKeys = const []}) async {
    await loggerService.initLogFile(
        userId: userId,
        userName: userName,
        env: env,
        apiKey: apiKey,
        appName: appName,
        url: url,
        maskKeys: maskKeys);
  }

  /// This function is used to store log into mobile directory
  static Future<void> log({required String message, String? logType}) async {
    await loggerService.log(message: message, logType: logType);
  }

  /// This function is used to get logs from mobile directory
  static Future<void> getLog() async {
    await loggerService.getLogFile();
  }

  /// This function is used to upload logs from mobile directory to server
  static Future uploadTodayLogs() async {
    await loggerService.uploadTodayLogs();
  }

  /// This function used to get the configuration of the user.
  static UserConfig getUserConfig() {
    return loggerService.getUserConfig();
  }

  /// This function used to set the configuration of the user.
  static void setUserConfig({required UserConfig config}) {
    loggerService.setUserConfig(config: config);
  }
}

enum LogType { custom, error, user, open }
