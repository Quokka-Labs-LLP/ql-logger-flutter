library ql_logger_flutter;

import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ql_logger_flutter/ql_logger_flutter.dart';
import 'package:ql_logger_flutter/src/api_services/dio_client.dart';
import 'package:ql_logger_flutter/src/device_info.dart';

import 'base_logger_service.dart';

class LoggerService extends BaseLoggerService {
  /// [_logFile] is used to create log file to [getApplicationDocumentsDirectory] directory
  File? _logFile;
  List<String> _maskKeys = [];
  String _url = '';

  /// This override function [initLogFile] will initialize the log file into mobile directory.
  @override
  Future<void> initLogFile(
      {String? userId,
      String? userName,
      required String env,
      required String apiToken,
      required String appName,
      required String url,
      List<String> maskKeys = const []}) async {
    /// [DeviceInfo.setDeviceInfo()] is used to set device/app information.
    DeviceInfo.setDeviceInfo();
    DeviceInfo.appName = appName;

    /// [_userId] is used to store particular logs of a particular user.
    DeviceInfo.userId = userId;
    DeviceInfo.userName = userName;

    /// assigning values to appEnv and apiKey
    DeviceInfo.appEnv = env;
    DeviceInfo.apiToken = apiToken;
    _maskKeys = maskKeys;
    _url = url;
    final directory = await getApplicationDocumentsDirectory();
    var logsDir = Directory('${directory.path}/logs');
    _logFile = File('${logsDir.path}/${_currentDate()}.txt');
    assert(_logFile != null, "unable to initialize log file");
    if (!(await _logFile!.exists())) {
      await _logFile?.create(recursive: true);
    }

    logsDir.listSync().map((element) async {
      File content = File(element.path);
      String permissionsContent = await _getPermissionStatus();
      String fileName = content.path.split('/').last;
      bool isLogsUploaded = await _uploadLogsApi(
          '$permissionsContent\n${content.readAsStringSync()}', fileName.replaceAll('.txt', ''),
          logType: DeviceInfo.userId != null ? LogType.user.name : LogType.open.name);
      if (isLogsUploaded) {
        if (!(fileName.contains('${_currentDate()}.txt'))) {
          element.deleteSync();
        } else {
          clearTodayLogs();
        }
      }
    }).toList();
  }

  @override
  Future<void> log({required String message, String? logType}) async {
    assert(_logFile != null, "Logger is not initialized");
    if (_logFile == null) return;
    final logEntry =
        '\n\n***************************************************************************'
        '\n${DeviceInfo.appName}(${DeviceInfo.deviceOS}) | ${DeviceInfo.appVersion} | ${DateTime.now().toUtc()}[UTC]   (appName | appVersion | time)'
        '\n${DeviceInfo.deviceDetail}\n'
        '\n${_maskUserData(message)}'
        '\n***************************************************************************';
    Isolate.run(
      () {
        _logFile?.writeAsStringSync(
          logEntry,
          mode: FileMode.append,
        );
      },
    );
    if (logType == LogType.error.name) {
      await _uploadLogsApi(logEntry, _currentDate(), logType: LogType.error.name);
    }
  }

  String _maskUserData(String content) {
    String maskKeys =
        '${_maskKeys.isEmpty ? '' : '${_maskKeys.join('|')}|'}password|pass|pwd|firstName|lastName|name|first_name|last_name|fName|lName';
    content = content.replaceAllMapped(RegExp('($maskKeys):\\s*([^\\s,}]+(?:\\s[^\\s,}]+)*)'),
        (match) => '${match.group(1)}: ********'); // this is used to mask user details.
    content = content.replaceAllMapped(
      RegExp(r'(\b\w)(\w+)(@\w+\.\w+\b)'), // this is used to mask email
      (match) => '${match.group(1)}${'*' * match.group(2)!.length}${match.group(3)}',
    );
    content = _maskPhoneNumbers(content);
    content = _maskDomains(content);
    debugPrint('my masked data: $content');
    return content;
  }

  String _maskDomains(String content) {
    // Regular expression to match domains and URLs
    RegExp domainRegex =
        RegExp(r'\b(?:https?://|www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?\b');

    // Replace all domains with '[REDACTED]'
    return content.replaceAll(domainRegex, '[REDACTED]');
  }

  String _maskPhoneNumbers(String content) {
    // Regex to match different mobile number formats
    final phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?(\d{2,4}[-.\s]?)?(\d{2,4}[-.\s]?)?(\d{4})');

    // Replace middle parts of the phone number with stars
    content = content.replaceAllMapped(
      phoneRegex,
      (match) => match[0] != null
          ? match[0]!.contains('.')
              ? match[0]!
              : '${match[0]!.substring(0, (match[0]!.length - 4)).replaceAll(RegExp(r'\d'), '*')}${match[0]!.substring(match[0]!.length - 4)}'
          : '',
    );
    return content;
  }

  @override
  Future<void> getLogFile() async {
    assert(_logFile != null, "Logger is not initialized");
    if (_logFile == null) return;
    _logFile?.readAsStringSync();
  }

  /// Delete the log file content after sending logs to the server
  @override
  Future<void> clearTodayLogs() async {
    assert(_logFile != null, "Logger is not initialized");
    if (_logFile == null) return;
    try {
      if (await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      debugPrint("Error deleting log file: $e");
    }
  }

  ///[uploadTodayLogs] is used to upload log file.
  @override
  Future uploadTodayLogs({String? logType}) async {
    try {
      assert(_logFile != null, "Logger is not initialized");
      if (_logFile == null) return;
      bool isLogsUploaded =
          await _uploadLogsApi(_logFile!.readAsStringSync(), _currentDate(), logType: logType);
      if (isLogsUploaded) {
        await clearTodayLogs();
      }
    } catch (error) {
      return error.toString();
    }
  }

  /// [_uploadLogsApi] method is used to call the server logs API.
  Future<bool> _uploadLogsApi(String log, String date, {String? logType}) async {
    if (log.isEmpty) return false;
    Dio dio = DioClient().provideDio();
    try {
      Map<String, dynamic> req = {
        /// project name should be same on panel
        "project": DeviceInfo.appName,

        /// app environment (dev, stage, prod)
        "env": DeviceInfo.appEnv,

        /// utc formatted date
        "date": date,

        /// type of logs you want to upload (currently we support [error] and [custom])
        "log_type": logType ?? "custom",

        /// the file name that will appear on the log panel.
        "log_name": _logName(),

        /// the content of the logs that you want to upload.
        "content": log
      };
      final apiResponse = await Isolate.run(
        () async => await dio.post(_url,
            data: req,
            options: Options(
                headers: {'Accept': 'application/json', 'Authorization': DeviceInfo.apiToken})),
      );
      return apiResponse.statusCode == 201;
    } catch (error) {
      return false;
    }
  }

  /// this function is used to get the log name based on whether the user ID exists or not.
  String _logName() {
    if (DeviceInfo.userId != null) {
      return '${DeviceInfo.userName ?? 'User'}_${DeviceInfo.userId ?? 'id'}.log';
    }
    return '${DeviceInfo.deviceID}.log';
  }

  /// this function is used to return the current date.
  String _currentDate() {
    /// [_dateTime] is used to get current time of user in utc.
    final DateTime dateTime = DateTime.now().toUtc();

    /// [_formatter] is used to change date format
    final formatter = DateFormat('d-M-yyyy');
    var formattedDate = formatter.format(dateTime);
    return formattedDate;
  }

  /// This function used to get the Configuration of the user.
  @override
  UserConfig getUserConfig() {
    return UserConfig(userId: DeviceInfo.userId, userName: DeviceInfo.userName);
  }

  /// This function used to set the Configuration of the user.
  @override
  void setUserConfig({required UserConfig config}) async {
    await uploadTodayLogs(
        logType: DeviceInfo.userId != null ? LogType.user.name : LogType.open.name);
    DeviceInfo.userName = config.userName;
    DeviceInfo.userId = config.userId;
  }

  /// This function used to get the permission status of all the permissions.
  Future<String> _getPermissionStatus() async {
    String permissionStatusText = '\n|||||||||||||||[PERMISSIONS]||||||||||||||||\n';
    permissionStatusText +=
        '||  Audio                      : ${(await Permission.audio.status).name}\t  ||\n'
        '||  Assistant                  : ${(await Permission.assistant.status).name}\t  ||\n'
        '||  AccessMediaLocation        : ${(await Permission.accessMediaLocation.status).name}\t  ||\n'
        '||  AccessNotificationPolicy   : ${(await Permission.accessNotificationPolicy.status).name}\t  ||\n'
        '||  ActivityRecognition        : ${(await Permission.activityRecognition.status).name}\t  ||\n'
        '||  AppTrackingTransparency    : ${(await Permission.appTrackingTransparency.status).name}\t  ||\n'
        '||  BackgroundRefresh          : ${(await Permission.backgroundRefresh.status).name}\t  ||\n'
        '||  Bluetooth                  : ${(await Permission.bluetooth.status).name}\t  ||\n'
        '||  BluetoothAdvertise         : ${(await Permission.bluetoothAdvertise.status).name}\t  ||\n'
        '||  BluetoothConnect           : ${(await Permission.bluetoothConnect.status).name}\t  ||\n'
        '||  BluetoothScan              : ${(await Permission.bluetoothScan.status).name}\t  ||\n'
        '||  Camera                     : ${(await Permission.camera.status).name}\t  ||\n'
        '||  CalendarFullAccess         : ${(await Permission.calendarFullAccess.status).name}\t  ||\n'
        '||  CalendarWriteOnly          : ${(await Permission.calendarWriteOnly.status).name}\t  ||\n'
        '||  Contacts                   : ${(await Permission.contacts.status).name}\t  ||\n'
        '||  CriticalAlerts             : ${(await Permission.criticalAlerts.status).name}\t  ||\n'
        '||  IgnoreBatteryOptimizations : ${(await Permission.ignoreBatteryOptimizations.status).name}\t  ||\n'
        '||  Location                   : ${(await Permission.location.status).name}\t  ||\n'
        '||  LocationWhenInUse          : ${(await Permission.locationWhenInUse.status).name}\t  ||\n'
        '||  LocationAlways             : ${(await Permission.locationAlways.status).name}\t  ||\n'
        '||  Microphone                 : ${(await Permission.microphone.status).name}\t  ||\n'
        '||  MediaLibrary               : ${(await Permission.mediaLibrary.status).name}\t  ||\n'
        '||  ManageExternalStorage      : ${(await Permission.manageExternalStorage.status).name}\t  ||\n'
        '||  Notification               : ${(await Permission.notification.status).name}\t  ||\n'
        '||  NearbyWifiDevices          : ${(await Permission.nearbyWifiDevices.status).name}\t  ||\n'
        '||  Phone                      : ${(await Permission.phone.status).name}\t  ||\n'
        '||  Photos                     : ${(await Permission.photos.status).name}\t  ||\n'
        '||  PhotosAddOnly              : ${(await Permission.photosAddOnly.status).name}\t  ||\n'
        '||  Reminders                  : ${(await Permission.reminders.status).name}\t  ||\n'
        '||  RequestInstallPackages     : ${(await Permission.requestInstallPackages.status).name}\t  ||\n'
        '||  Storage                    : ${(await Permission.storage.status).name}\t  ||\n'
        '||  SMS                        : ${(await Permission.sms.status).name}\t  ||\n'
        '||  SystemAlertWindow          : ${(await Permission.systemAlertWindow.status).name}\t  ||\n'
        '||  Speech                     : ${(await Permission.speech.status).name}\t  ||\n'
        '||  Sensors                    : ${(await Permission.sensors.status).name}\t  ||\n'
        '||  SensorsAlways              : ${(await Permission.sensorsAlways.status).name}\t  ||\n'
        '||  ScheduleExactAlarm         : ${(await Permission.scheduleExactAlarm.status).name}\t  ||\n'
        '||  Videos                     : ${(await Permission.videos.status).name}\t  ||\n';
    permissionStatusText += '||||||||||||||||||||||||||||||||||||||||||||\n';
    return permissionStatusText;
  }
}
