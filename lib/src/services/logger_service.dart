import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
  Future<void> initLogFile({
    String? userId,
    String? userName,
    required String env,
    required String apiToken,
    required String appName,
    required String url,
    List<String> maskKeys = const [],
  }) async {
    // Initialize device info
    DeviceInfo deviceInfo = DeviceInfo.instance;
    deviceInfo.setDeviceInfo(); // Sets basic device/app details
    deviceInfo.appName = appName;
    deviceInfo.userId = userId;
    deviceInfo.userName = userName;
    deviceInfo.appEnv = env;
    deviceInfo.apiToken = apiToken;

    // Store global configuration
    _maskKeys = maskKeys;
    _url = url;

    // Get application's document directory (used for storing logs)
    final directory = await getApplicationDocumentsDirectory();
    var logsDir = Directory('${directory.path}/logs');

    // Initialize the log file for the current date
    _logFile = File('${logsDir.path}/${_currentDate()}.txt');
    assert(_logFile != null, "Unable to initialize log file");

    // Ensure log file exists before writing
    if (!(await _logFile!.exists())) {
      await _logFile?.create(recursive: true);
    }

    // Process existing logs safely
    await for (var file in logsDir.list()) {
      if (file is File) {
        await _processLogFile(file);
      }
    }
  }

  /// Safe function to process log files
  Future<void> _processLogFile(File file) async {
    try {
      // Get permissions info (if required for logging)
      String permissionsContent = await _getPermissionStatus();

      // Read log file safely with fallback
      String logData = await _safeReadLogFile(file);

      // Extract filename (e.g., "5-3-2025.txt")
      String fileName = file.path.split('/').last;

      /// Upload log file to server
      bool isLogsUploaded = await _uploadLogsApi(
        '$permissionsContent\n$logData', // Send log content with permissions info
        fileName.replaceAll('.txt', ''), // Remove ".txt" for filename
        logType: DeviceInfo.instance.userId != null
            ? LogType.user.name
            : LogType.open.name,
      );

      /// Cleanup old logs if successfully uploaded
      if (isLogsUploaded) {
        if (!fileName.contains('${_currentDate()}.txt')) {
          await file.delete(); // Safely delete old logs
        } else {
          await clearTodayLogs(); // Clear only today's logs after upload
        }
      }
    } catch (e) {
      assert(!kDebugMode, "Error processing log file: $e");
    }
  }

  /// Safe function to read log files (prevents UTF-8 decoding errors)
  Future<String> _safeReadLogFile(File file) async {
    try {
      // Attempt to read the file normally
      return await file.readAsString(encoding: utf8);
    } catch (e) {
      assert(!kDebugMode, "UTF-8 Decoding Failed, Reading as Bytes: $e");
      return await _readWithFallback(file);
    }
  }

  /// Fallback method: Read log file as bytes to prevent `FileSystemException`
  Future<String> _readWithFallback(File file) async {
    try {
      // Read file as bytes (raw data)
      List<int> bytes = await file.readAsBytes();

      // Decode bytes using UTF-8 with `allowMalformed: true` to prevent crashes
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      assert(!kDebugMode, "Failed to read file even as bytes: $e");
      return "ERROR: Unable to read log file"; // Return error message instead of crashing
    }
  }

  @override
  Future<void> log({required String message, String? logType}) async {
    assert(_logFile != null, "Logger is not initialized");
    if (_logFile == null) return;

    DeviceInfo deviceInfo = DeviceInfo.instance;
    final logEntry = '''
  
***************************************************************************
${deviceInfo.appName}(${deviceInfo.deviceOS}) | ${deviceInfo.appVersion} | ${DateTime.now().toUtc()}[UTC] | ${DateTime.now().toLocal()}[${DateTime.now().toLocal().timeZoneName}, ${DateTime.now().toLocal().timeZoneOffset}]
(appName | appVersion | time(UTC) | time(Local))
${deviceInfo.deviceDetail}

${_maskUserData(message)}
***************************************************************************
  ''';

    // Asynchronous File Writing
    try {
      await _logFile!.writeAsString(
        logEntry,
        mode: FileMode.append,
        flush: true, // Ensures data is written immediately
      );
    } catch (e) {
      assert(!kDebugMode, "Error writing log: $e");
    }

    // Handle Error Log Upload
    if (logType == LogType.error.name) {
      await _uploadLogsApi(logEntry, _currentDate(),
          logType: LogType.error.name);
    }
  }

  String _maskUserData(String content) {
    String maskKeys =
        '${_maskKeys.isEmpty ? '' : '${_maskKeys.join('|')}|'}password|pass|pwd|firstName|lastName|name|first_name|last_name|fName|lName';
    content = content.replaceAllMapped(
        RegExp('($maskKeys):\\s*([^\\s,}]+(?:\\s[^\\s,}]+)*)'),
        (match) =>
            '${match.group(1)}: ********'); // this is used to mask user details.
    content = content.replaceAllMapped(
      RegExp(r'(\b\w)(\w+)(@\w+\.\w+\b)'), // this is used to mask email
      (match) =>
          '${match.group(1)}${'*' * match.group(2)!.length}${match.group(3)}',
    );
    content = _maskPhoneNumbers(content);
    content = _maskDomains(content);
    debugPrint('my masked data: $content');
    return content;
  }

  String _maskDomains(String content) {
    // Regular expression to match domains and URLs
    RegExp domainRegex = RegExp(
        r'\b(?:https?://|www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?\b');

    // Replace all domains with '[REDACTED]'
    return content.replaceAll(domainRegex, '[REDACTED]');
  }

  String _maskPhoneNumbers(String content) {
    // Regex to match different mobile number formats
    final phoneRegex = RegExp(
        r'(\+?\d{1,3}[-.\s]?)?(\d{2,4}[-.\s]?)?(\d{2,4}[-.\s]?)?(\d{4})');

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
  Future<String> getLogFile() async {
    assert(_logFile != null, "Logger is not initialized");
    if (_logFile == null) return '';
    return _logFile?.readAsStringSync() ?? '';
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
      assert(!kDebugMode, "Error deleting log file: $e");
    }
  }

  ///[uploadTodayLogs] is used to upload log file.
  @override
  Future<String> uploadTodayLogs({String? logType}) async {
    try {
      // Check if logger is initialized
      if (_logFile == null) {
        return 'Logger is not initialized.';
      }

      // Read file asynchronously & safely
      String logData = await _safeReadLogFile(_logFile!);

      // Upload logs via API
      bool isLogsUploaded =
          await _uploadLogsApi(logData, _currentDate(), logType: logType);

      // Clear logs if successfully uploaded
      if (isLogsUploaded) {
        await clearTodayLogs();
        return 'Logs uploaded successfully.';
      } else {
        return 'Error uploading logs.';
      }
    } catch (error) {
      // Catch unexpected errors and return them
      return 'Upload failed: ${error.toString()}';
    }
  }

  /// [_uploadLogsApi] method is used to call the server logs API.
  Future<bool> _uploadLogsApi(String log, String date,
      {String? logType}) async {
    if (log.isEmpty) return false;
    Dio dio = DioClient().provideDio();
    try {
      DeviceInfo deviceInfo = DeviceInfo.instance;
      Map<String, dynamic> req = {
        /// project name should be same on panel
        "project": deviceInfo.appName,

        /// app environment (dev, stage, prod)
        "env": deviceInfo.appEnv,

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
            options: Options(headers: {
              'Accept': 'application/json',
              'Authorization': deviceInfo.apiToken
            })),
      );
      return apiResponse.statusCode == 201;
    } catch (error) {
      return false;
    }
  }

  /// this function is used to get the log name based on whether the user ID exists or not.
  String _logName() {
    DeviceInfo deviceInfo = DeviceInfo.instance;
    if (deviceInfo.userId != null) {
      return '${deviceInfo.userName ?? 'User'}_${deviceInfo.userId ?? 'id'}.log';
    }
    return '${deviceInfo.deviceID}.log';
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
    DeviceInfo deviceInfo = DeviceInfo.instance;
    return UserConfig(userId: deviceInfo.userId, userName: deviceInfo.userName);
  }

  /// This function used to set the Configuration of the user.
  @override
  void setUserConfig({required UserConfig config}) async {
    DeviceInfo deviceInfo = DeviceInfo.instance;
    await uploadTodayLogs(
        logType:
            deviceInfo.userId != null ? LogType.user.name : LogType.open.name);
    deviceInfo.userName = config.userName;
    deviceInfo.userId = config.userId;
  }

  /// This function used to get the permission status of all the permissions.
  Future<String> _getPermissionStatus() async {
    String permissionStatusText =
        '\n|||||||||||||||[PERMISSIONS]||||||||||||||||\n';
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
