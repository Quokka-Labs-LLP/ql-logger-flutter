import 'package:ql_logger_flutter/ql_logger_flutter.dart';

abstract class BaseLoggerService {
  void initLogFile(
      {String userId,
      String? userName,
      required String env,
      required String apiToken,
      required String appName,
      required String url,
      List<String> maskKeys = const [],
      int durationInMin = 3});
  Future<void> log({required String message, LogType? logType});
  Future<void> getLogFile();
  Future<void> clearTodayLogs();
  UserConfig getUserConfig();
  void setUserConfig({required UserConfig config});
  Future<String> uploadTodayLogs();
}
