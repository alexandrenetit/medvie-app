// lib/core/errors/api_exception.dart
import 'api_error.dart';

class ApiException implements Exception {
  final ApiError error;

  const ApiException(this.error);

  int get statusCode => error.statusCode;
  String? get code => error.code;
  String? get description => error.description;

  bool get isBadRequest => error.isBadRequest;
  bool get isUnauthorized => error.isUnauthorized;
  bool get isForbidden => error.isForbidden;
  bool get isNotFound => error.isNotFound;
  bool get isValidation => error.isValidation;
  bool get isRateLimited => error.isRateLimited;
  bool get isServerError => error.isServerError;

  @override
  String toString() => error.toString();
}
