import 'package:flutter/services.dart';

class ScreenStateService {
  static const _channel = MethodChannel('timemanager/screen_state');

  Future<bool> isScreenLocked() async {
    try {
      return await _channel.invokeMethod<bool>('isScreenLocked') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
