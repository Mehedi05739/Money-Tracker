import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Opens the system screens that control whether notifications arrive.
///
/// A blocked notification channel, a denied permission and a withheld
/// "Alarms & reminders" grant can none of them be fixed by the app — only by
/// the user, in settings. Sending them straight to the right screen is the
/// difference between a fixable problem and an app that just does not work.
///
/// A tiny platform channel rather than a package: three intents do not justify
/// a dependency.
class SystemSettings {
  const SystemSettings._();

  static const MethodChannel _channel = MethodChannel(
    'money_tracker/system_settings',
  );

  static Future<bool> openNotificationSettings() =>
      _invoke('openNotificationSettings');

  /// Opens one channel's settings, where a blocked channel is turned back on.
  static Future<bool> openChannelSettings(String channelId) =>
      _invoke('openChannelSettings', {'channelId': channelId});

  static Future<bool> openExactAlarmSettings() =>
      _invoke('openExactAlarmSettings');

  static Future<bool> _invoke(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } catch (error) {
      // Only Android implements this, and some builds lack the screen.
      AppLogger.w(
        'Could not open $method: ${error.runtimeType}',
        name: 'SETTINGS',
      );
      return false;
    }
  }
}
