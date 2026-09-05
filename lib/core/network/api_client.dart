import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

import '../constants/app_constants.dart';
import '../constants/storage_keys.dart';
import '../errors/exceptions.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';
import 'api_endpoints.dart';

/// Single HTTP entry point, built on `GetConnect`.
///
/// Returns decoded bodies and throws typed [AppException]s; data sources are
/// the only layer that talks to it.
class ApiClient extends GetConnect {
  ApiClient(this._storage);

  final StorageService _storage;

  @override
  void onInit() {
    httpClient.baseUrl = ApiEndpoints.baseUrl;
    httpClient.timeout = AppConstants.connectTimeout;

    httpClient.addRequestModifier<Object?>((request) {
      final token = _storage.getString(StorageKeys.accessToken);
      request.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      AppLogger.d('${request.method.toUpperCase()} ${request.url}', name: 'HTTP');
      return request;
    });

    httpClient.addResponseModifier((request, response) {
      AppLogger.d('${response.statusCode} ${request.url}', name: 'HTTP');
      return response;
    });

    super.onInit();
  }

  Future<T> getRequest<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic body)? decoder,
  }) =>
      _send(() => get(path, query: _stringify(query)), decoder);

  Future<T> postRequest<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(dynamic body)? decoder,
  }) =>
      _send(() => post(path, body, query: _stringify(query)), decoder);

  Future<T> putRequest<T>(
    String path, {
    Object? body,
    T Function(dynamic body)? decoder,
  }) =>
      _send(() => put(path, body), decoder);

  Future<T> patchRequest<T>(
    String path, {
    Object? body,
    T Function(dynamic body)? decoder,
  }) =>
      _send(() => patch(path, body), decoder);

  Future<T> deleteRequest<T>(
    String path, {
    T Function(dynamic body)? decoder,
  }) =>
      _send(() => delete(path), decoder);

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic body)? decoder,
  ) async {
    final Response<dynamic> response;
    try {
      response = await request();
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Request timed out');
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.e('Unhandled request error', error: error, stackTrace: stackTrace);
      throw ServerException('$error');
    }

    return _handle(response, decoder);
  }

  T _handle<T>(Response<dynamic> response, T Function(dynamic body)? decoder) {
    final status = response.statusCode ?? 0;

    if (status == 401) {
      throw UnauthorizedException(_messageOf(response) ?? 'Unauthorized');
    }
    if (!response.isOk) {
      throw ServerException(
        _messageOf(response) ?? response.statusText ?? 'Request failed',
        statusCode: status,
      );
    }

    if (decoder == null) return response.body as T;
    try {
      return decoder(response.body);
    } catch (error, stackTrace) {
      AppLogger.e('Decode failed', error: error, stackTrace: stackTrace);
      throw const ParseException();
    }
  }

  String? _messageOf(Response<dynamic> response) {
    final body = response.body;
    if (body is Map && body['message'] is String) return body['message'] as String;
    if (body is Map && body['error'] is String) return body['error'] as String;
    return null;
  }

  Map<String, dynamic>? _stringify(Map<String, dynamic>? query) {
    if (query == null) return null;
    return query.map((key, value) => MapEntry(key, value?.toString()))
      ..removeWhere((_, value) => value == null);
  }
}
