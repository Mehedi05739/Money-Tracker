import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Reading and writing files the *user* owns, through the system picker.
///
/// Everything the app writes to its own storage — under
/// `/data/user/0/<package>` — is deleted when the app is uninstalled. A backup
/// kept there disappears at exactly the moment it is needed, so a file meant to
/// survive a reinstall has to live somewhere the user chose: Downloads, Drive,
/// an SD card.
///
/// The Storage Access Framework does that without any storage permission: the
/// user picks the location, and the app is handed one document. A small
/// platform channel rather than a package, since it is two calls.
class DocumentStore {
  const DocumentStore._();

  static const MethodChannel _channel = MethodChannel(
    'money_tracker/documents',
  );

  /// Raised when the device has no picker, or the file could not be read or
  /// written. Cancelling is not one of these — that returns null.
  static const String unavailable = 'unavailable';

  /// Writes [content] to a file the user chooses.
  ///
  /// Returns the file's name, or null if the user backed out.
  static Future<String?> save({
    required String fileName,
    required String content,
    String mimeType = 'application/json',
  }) async {
    try {
      return await _channel.invokeMethod<String>('saveDocument', {
        'fileName': fileName,
        'mimeType': mimeType,
        'content': content,
      });
    } on PlatformException catch (error) {
      AppLogger.w('Could not save document: ${error.code}', name: 'DOCS');
      rethrow;
    } on MissingPluginException {
      // Only Android implements this today.
      throw PlatformException(
        code: unavailable,
        message: 'Saving to a file is not supported on this platform',
      );
    }
  }

  /// Reads a file the user chooses. Returns null if they backed out.
  static Future<String?> pick({
    List<String> mimeTypes = const ['application/json', 'text/plain'],
  }) async {
    try {
      return await _channel.invokeMethod<String>('openDocument', {
        'mimeTypes': mimeTypes,
      });
    } on PlatformException catch (error) {
      AppLogger.w('Could not read document: ${error.code}', name: 'DOCS');
      rethrow;
    } on MissingPluginException {
      throw PlatformException(
        code: unavailable,
        message: 'Opening a file is not supported on this platform',
      );
    }
  }
}
