import 'package:ql_logger_flutter/src/model/user_config_model.dart';

abstract class BaseLoggerService {
  Future<void> initLogFile(
      {String userId,
      String? userName,
      required String env,
      required String apiToken,
      required String appName,
      required String url,
      List<String> maskKeys = const []});
  Future<void> log({required String message, String? logType});
  Future<void> getLogFile();
  Future<void> clearTodayLogs();
  UserConfig getUserConfig();
  void setUserConfig({required UserConfig config});
  Future uploadTodayLogs();
}
