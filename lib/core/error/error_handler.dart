import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'app_exception.dart';

/// 전역 에러 핸들러
/// DioException, Exception 등을 AppException으로 변환하고 처리
class ErrorHandler {
  ErrorHandler._();

  /// DioException을 AppException으로 변환
  static AppException handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException.timeout(originalError: error);

      case DioExceptionType.connectionError:
        return AppException.network(originalError: error);

      case DioExceptionType.cancel:
        return AppException.cancelled(originalError: error);

      case DioExceptionType.badResponse:
        return _handleStatusCode(error.response, error);

      case DioExceptionType.badCertificate:
        return AppException.network(
          message: '보안 인증서 오류가 발생했습니다',
          originalError: error,
        );

      case DioExceptionType.unknown:
      default:
        // 네트워크 연결 문제인지 확인
        if (error.error != null &&
            error.error.toString().contains('SocketException')) {
          return AppException.network(originalError: error);
        }
        return AppException.unknown(originalError: error);
    }
  }

  /// HTTP 상태 코드에 따른 에러 처리
  static AppException _handleStatusCode(Response? response, dynamic originalError) {
    final statusCode = response?.statusCode ?? 0;
    final data = response?.data;

    // 서버에서 에러 메시지를 보낸 경우 추출
    String? serverMessage;
    String? errorCode;

    if (data is Map<String, dynamic>) {
      serverMessage = data['message'] as String? ??
          data['error'] as String? ??
          data['msg'] as String?;
      errorCode = data['code']?.toString();
    }

    switch (statusCode) {
      case 400:
        return AppException.validation(
          message: serverMessage,
          code: errorCode,
          originalError: originalError,
        );
      case 401:
        return AppException.unauthorized(
          message: serverMessage,
          originalError: originalError,
        );
      case 403:
        return AppException.forbidden(
          message: serverMessage,
          originalError: originalError,
        );
      case 404:
        return AppException.notFound(
          message: serverMessage,
          originalError: originalError,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return AppException.server(
          message: serverMessage,
          code: errorCode,
          originalError: originalError,
        );
      default:
        return AppException.unknown(
          message: serverMessage,
          originalError: originalError,
        );
    }
  }

  /// 일반 Exception을 AppException으로 변환
  static AppException handleError(dynamic error) {
    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      return handleDioError(error);
    }

    if (error is FormatException) {
      return AppException.validation(
        message: '데이터 형식이 올바르지 않습니다',
        originalError: error,
      );
    }

    return AppException.unknown(
      message: error?.toString(),
      originalError: error,
    );
  }

  /// 에러 메시지를 사용자 친화적으로 변환
  static String getUserFriendlyMessage(dynamic error) {
    final appException = handleError(error);
    return appException.message;
  }

  /// 에러 로깅 (추후 Firebase Crashlytics 등 연동 가능)
  static void logError(dynamic error, [StackTrace? stackTrace]) {
    final appException = handleError(error);
    debugPrint('[ERROR] ${appException.type}: ${appException.message}');
    if (stackTrace != null) {
      debugPrint('[STACK] $stackTrace');
    }
    // TODO: Firebase Crashlytics 연동
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }
}

/// GlobalKey for showing snackbars without context
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 전역 스낵바 표시 유틸
class SnackBarUtils {
  SnackBarUtils._();

  /// 에러 스낵바 표시
  static void showError(String message, {Duration? duration}) {
    _showSnackBar(
      message,
      backgroundColor: Colors.red.shade700,
      icon: Icons.error_outline,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// 성공 스낵바 표시
  static void showSuccess(String message, {Duration? duration}) {
    _showSnackBar(
      message,
      backgroundColor: Colors.green.shade700,
      icon: Icons.check_circle_outline,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// 경고 스낵바 표시
  static void showWarning(String message, {Duration? duration}) {
    _showSnackBar(
      message,
      backgroundColor: Colors.orange.shade700,
      icon: Icons.warning_amber_outlined,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// 정보 스낵바 표시
  static void showInfo(String message, {Duration? duration}) {
    _showSnackBar(
      message,
      backgroundColor: Colors.blue.shade700,
      icon: Icons.info_outline,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// AppException 기반 스낵바 표시
  static void showException(AppException exception) {
    if (exception.type == AppExceptionType.cancelled) {
      return; // 취소된 요청은 표시하지 않음
    }

    showError(exception.message);
  }

  static void _showSnackBar(
    String message, {
    required Color backgroundColor,
    required IconData icon,
    required Duration duration,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) {
      debugPrint('[SnackBar] ScaffoldMessenger not available: $message');
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
