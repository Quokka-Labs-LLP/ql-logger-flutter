import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfo {
  static final DeviceInfo _instance = DeviceInfo._internal();
  DeviceInfo._internal();
  static DeviceInfo get instance => _instance;

  /// Static variables to store device information
  String deviceOS = "";
  String appName = "";
  String appVersion = "";
  String appEnv = "";
  String apiToken = "";
  String? userId;
  String? userName;
  String? deviceDetail;
  String? deviceID;

  /// Method used to set device information
  Future<void> setDeviceInfo() async {
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
