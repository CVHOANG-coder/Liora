import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum ImageAccessPermissionResult { granted, denied, settingsRequired }

abstract final class ImageAccessPermission {
  static Future<ImageAccessPermissionResult> request(ImageSource source) async {
    final permission = await _permissionFor(source);
    if (permission == null) return ImageAccessPermissionResult.granted;

    var status = await permission.status;
    if (_isAllowed(status)) return ImageAccessPermissionResult.granted;
    if (_requiresSettings(status)) {
      return ImageAccessPermissionResult.settingsRequired;
    }

    status = await permission.request();
    if (_isAllowed(status)) return ImageAccessPermissionResult.granted;
    if (_requiresSettings(status)) {
      return ImageAccessPermissionResult.settingsRequired;
    }
    return ImageAccessPermissionResult.denied;
  }

  static Future<bool> openSettings() => openAppSettings();

  static Future<Permission?> _permissionFor(ImageSource source) async {
    if (source == ImageSource.camera) return Permission.camera;
    if (Platform.isIOS) return Permission.photos;

    // Android's system Photo Picker grants access only to the selected image.
    // Requesting broad media/storage permission here can incorrectly block the
    // picker on newer Android versions and is unnecessary on older versions
    // where image_picker falls back to ACTION_GET_CONTENT.
    if (Platform.isAndroid) return null;
    return null;
  }

  static bool _isAllowed(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  static bool _requiresSettings(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;
}
