import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ql_logger_flutter/ql_logger_flutter.dart';
import 'package:ql_logger_flutter/src/api_services/dio_client.dart';
import 'package:ql_logger_flutter/src/device_info.dart';
import 'package:ql_logger_flutter/src/services/timer_service.dart';

import 'base_logger_service.dart';

class LoggerService extends BaseLoggerService {
  /// [_logFile] is used to create log file to [getApplicationDocumentsDirectory] directory
  File? _logFile;
  List<String> _maskKeys = [];
  String _url = '';
  bool _recordPermissionLogs = true;
  bool _isInitialized = false;

  /// [logUploadingResponse] is used to log the API response after uploading logs.
  Function(Response<dynamic> response)? logUploadingResponse;

  /// [onLogUploadingError] is used to handle errors that occur during log uploading.
  Function(dynamic onError)? onLogUploadingError;

  /// [onException] is used to capture errors that occur during an asynchronous call.
  Function(dynamic onError)? onException;

  bool get isInitialized => _isInitialized;

  /// [_isRecordNetworkLogs] is used to enable or disable recording of network connection logs.
  bool _isRecordNetworkLogs = false;

  /// This override function [initLogFile] will initialize the log file into mobile directory.
  @override
  void initLogFile(
      {String? userId,
      String? userName,
      required String env,
      required String apiToken,
      required String appName,
      required String url,
      List<String> maskKeys = const [],
      bool recordPermission = true,
      int durationInMin = 3,
      recordNetworkLogs = false}) async {
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
    _recordPermissionLogs = recordPermission;
    _isRecordNetworkLogs = recordNetworkLogs;
    _handleLogFiles(durationInMin);
  }

  /// [_handleLogFiles] is used to create and process log files for upload.
  Future<void> _handleLogFiles(int durationInMin) async {
    // Get application's document directory (used for storing logs)
    final directory = await getApplicationDocumentsDirectory();
    var logsDir = Directory('${directory.path}/logs');

    // Initialize the log file for the current date
    _logFile = File('${logsDir.path}/${_currentDate()}.txt');
    assert(_logFile != null, "Unable to initialize log file");
    // Ensure log file exists before writing
    await _createLogFile();

    // Process existing logs safely
    await for (var file in logsDir.list()) {
      if (file is File) {
        await _processLogFile(file);
      }
    }

    ///[TimerService.startTimer] starts a timer to upload logs at a specific interval.
    TimerService.startTimer(durationInMin, onSuccess: () async {
      DeviceInfo deviceInfo = DeviceInfo.instance;
      await uploadTodayLogs(
          logType: deviceInfo.userId != null ? LogType.user : LogType.open);
    });
  }

  /// Safe function to process log files
  Future<void> _processLogFile(File file) async {
    try {
      // Get permissions info (if required for logging)
      String permissionsContent = '';

      // Permission handler only work for Android, iOS, Web and Windows environment
      if ((Platform.isAndroid ||
              Platform.isIOS ||
              Platform.isWindows ||
              kIsWeb) &&
          _recordPermissionLogs) {
        permissionsContent = await _getPermissionStatus();
      }

      // Read log file safely with fallback
      String logData = await _safeReadLogFile(file);

      // Extract filename (e.g., "5-3-2025.txt")
      String fileName = file.path.split('/').last;

      /// Upload log file to server
      bool isLogsUploaded = await _uploadLogsApi(
        // Send log content with permissions info
        '$permissionsContent\n$logData',
        fileName.replaceAll('.txt', ''), // Remove ".txt" for filename
        logType:
            DeviceInfo.instance.userId != null ? LogType.user : LogType.open,
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
      if (onException != null) {
        onException!(e);
      }
      assert(!kDebugMode, "Error processing log file: $e");
    }
  }

  /// Safe function to read log files (prevents UTF-8 decoding errors)
  Future<String> _safeReadLogFile(File file) async {
    try {
      // Attempt to read the file normally
      return await file.readAsString(encoding: utf8);
    } catch (e) {
      if (onException != null) {
        onException!(e);
      }
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
      if (onException != null) {
        onException!(e);
      }
      assert(!kDebugMode, "Failed to read file even as bytes: $e");
      return "ERROR: Unable to read log file"; // Return error message instead of crashing
    }
  }

  /// [_internetConnectionChecker] checks the current network connectivity status
  Future<(String, String)> _internetConnectionChecker() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());
    String connectedNetworks = connectivityResult
        .map(
          (e) => e.name,
        )
        .join(', ');
    String networkStrength = '';
    if (Platform.isAndroid) {
      if (connectivityResult.contains(ConnectivityResult.mobile)) {
        networkStrength = await _checkInternetStrength(true);
      } else if (connectivityResult.contains(ConnectivityResult.wifi)) {
        networkStrength = await _checkInternetStrength(false);
      }
    }
    return (connectedNetworks, networkStrength);
  }

  ///[_checkInternetStrength] checks the signal strength of the current network connection.
  /// [_checkInternetStrength] is supported only on Android.
  Future<String> _checkInternetStrength(bool isConnectedToMobile) async {
    final FlutterInternetSignal internetSignal = FlutterInternetSignal();
    int? signal;
    if (isConnectedToMobile) {
      signal = await internetSignal.getMobileSignalStrength();
    } else {
      signal = await internetSignal.getWifiSignalStrength();
    }
    return '${_getNetworkStrength(signal ?? 0)}(${signal}dBm)';
  }

  ///[_getNetworkStrength] returns a descriptive network strength category based on the signal strength in dBm.
  String _getNetworkStrength(int dBm) {
    if (dBm >= -50) return NetworkStrengthType.excellent.name;
    if (dBm >= -60) return NetworkStrengthType.veryGood.name;
    if (dBm >= -70) return NetworkStrengthType.good.name;
    if (dBm >= -85) return NetworkStrengthType.fair.name;
    if (dBm >= -100) return NetworkStrengthType.weak.name;
    return NetworkStrengthType.poor.name;
  }

  @override
  Future<void> log(
      {required String message,
      LogType? logType,
      recordNetworkLogs = false}) async {
    assert(_logFile != null, "Logger is not initialized");

    /// Creates the log file if [_logFile] is not created or is null.
    if (_logFile == null) {
      await _createLogFile();
    }
    String networkLogs = '';
    if (_isRecordNetworkLogs || recordNetworkLogs) {
      (String, String) internetData = await _internetConnectionChecker();
      networkLogs = '''
      \n ( ${internetData.$1} ${Platform.isAndroid ? '| ${internetData.$2}' : ''}) |  ( networkConnectionType ${Platform.isAndroid ? ' | networkStrength' : ''} )
      ''';
    }
    DeviceInfo deviceInfo = DeviceInfo.instance;

    final logEntry = '''
***************************************************************************
${deviceInfo.appName}(${deviceInfo.deviceOS}) | ${deviceInfo.appVersion} | ${DateTime.now().toUtc()}[UTC] | ${DateTime.now().toLocal()}[${DateTime.now().toLocal().timeZoneName}, ${DateTime.now().toLocal().timeZoneOffset}]
(appName | appVersion(buildNumber) | time(UTC) | time(Local))
${deviceInfo.deviceDetail} $networkLogs

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
      if (onException != null) {
        onException!(e);
      }
      assert(!kDebugMode, "Error writing log: $e");
    }

    // Handle Error Log Upload
    if (logType == LogType.error) {
      await _uploadLogsApi(logEntry, _currentDate(), logType: LogType.error);
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
    /// Creates the log file if [_logFile] is not created or is null.
    if (_logFile == null) {
      await _createLogFile();
    }
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
      if (onException != null) {
        onException!(e);
      }
      assert(!kDebugMode, "Error deleting log file: $e");
    }
  }

  ///[uploadTodayLogs] is used to upload log file.
  @override
  Future<String> uploadTodayLogs({LogType? logType}) async {
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
      if (onException != null) {
        onException!(error);
      }
      // Catch unexpected errors and return them
      return 'Upload failed: ${error.toString()}';
    }
  }

  /// [_uploadLogsApi] method is used to call the server logs API.
  Future<bool> _uploadLogsApi(String log, String date,
      {LogType? logType}) async {
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
        "log_type": logType?.name ?? "custom",

        /// the file name that will appear on the log panel.
        "log_name": _logName(),

        /// the content of the logs that you want to upload.
        "content": log
      };
      Response apiResponse = await Isolate.run(
        () async => await dio.post(_url,
            data: req,
            options: Options(headers: {
              'Accept': 'application/json',
              'Authorization': deviceInfo.apiToken
            })),
      );

      if (logUploadingResponse != null) {
        logUploadingResponse!(apiResponse);
      }
      return apiResponse.statusCode == 201;
    } catch (error) {
      if (onLogUploadingError != null) {
        onLogUploadingError!(error);
      }
      return false;
    }
  }

  /// [_createLogFile] creates a log file if it does not already exist.
  Future _createLogFile() async {
    if (!(await _logFile?.exists() ?? false)) {
      final directory = await getApplicationDocumentsDirectory();
      var logsDir = Directory('${directory.path}/logs');
      // Initialize the log file for the current date
      _logFile = File('${logsDir.path}/${_currentDate()}.txt');
      await _logFile?.create(recursive: true);
    }
    _isInitialized = _logFile != null;
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
        logType: deviceInfo.userId != null ? LogType.user : LogType.open);
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
