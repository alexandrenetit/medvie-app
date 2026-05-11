// lib/core/errors/api_error.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiError {
  final int statusCode;
  final String? code;
  final String? description;
  final String? rawBody;

  const ApiError({
    required this.statusCode,
    this.code,
    this.description,
    this.rawBody,
  });

  factory ApiError.from(http.Response response) {
    final body = response.body;

    if (body.isEmpty) {
      return ApiError(statusCode: response.statusCode);
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final code = decoded['code'] as String?;
        final description = decoded['description'] as String?;
        final hasUsefulKeys = code != null || description != null;
        return ApiError(
          statusCode: response.statusCode,
          code: code,
          description: description,
          rawBody: hasUsefulKeys ? null : _truncate(body),
        );
      }
    } catch (_) {}

    return ApiError(
      statusCode: response.statusCode,
      rawBody: _truncate(body),
    );
  }

  static String _truncate(String s) =>
      s.length > 500 ? s.substring(0, 500) : s;

  bool get isBadRequest => statusCode == 400;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422;
  bool get isRateLimited => statusCode == 429;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiError($statusCode, $code): $description';
}
