import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfo {
  /// Private constructor to prevent instantiation.
  DeviceInfo._privateConstructor();

  /// Static variables to store device information
  static String deviceOS = "";
  static String appName = "";
  static String appVersion = "";
  static String appEnv = "";
  static String apiToken = "";
  static String? userId;
  static String? userName;
  static String? deviceDetail;
  static String? deviceID;

  /// Method used to set device information
  static void setDeviceInfo() async {
    final info = await PackageInfo.fromPlatform();
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      deviceOS = 'ios';
      var iosDeviceInfo = await deviceInfo.iosInfo;
      deviceID = iosDeviceInfo.identifierForVendor;
      deviceDetail =
          '${iosDeviceInfo.name} | ${iosDeviceInfo.systemVersion} | $deviceID   (deviceName | osVersion | deviceId)';
    } else if (Platform.isAndroid) {
      deviceOS = 'android';
      var androidDeviceInfo = await deviceInfo.androidInfo;
      deviceID = androidDeviceInfo.id;
      deviceDetail =
          '${androidDeviceInfo.brand} | ${androidDeviceInfo.version.release} | $deviceID   (deviceName | osVersion | deviceId)';
    }
    appVersion = info.version;
  }
}
