/// 앱 전역 예외 클래스
/// 모든 에러를 일관된 형태로 처리하기 위한 커스텀 예외
class AppException implements Exception {
  final String message;
  final String? code;
  final AppExceptionType type;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.type = AppExceptionType.unknown,
    this.originalError,
  });

  /// 네트워크 연결 에러
  factory AppException.network({String? message, dynamic originalError}) {
    return AppException(
      message: message ?? '네트워크 연결을 확인해주세요',
      type: AppExceptionType.network,
      originalError: originalError,
    );
  }

  /// 서버 에러 (5xx)
  factory AppException.server({String? message, String? code, dynamic originalError}) {
    return AppException(
      message: message ?? '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요',
      code: code,
      type: AppExceptionType.server,
      originalError: originalError,
    );
  }

  /// 인증 에러 (401)
  factory AppException.unauthorized({String? message, dynamic originalError}) {
    return AppException(
      message: message ?? '로그인이 필요합니다',
      type: AppExceptionType.unauthorized,
      originalError: originalError,
    );
  }

  /// 권한 에러 (403)
  factory AppException.forbidden({String? message, dynamic originalError}) {
    return AppException(
      message: message ?? '접근 권한이 없습니다',
      type: AppExceptionType.forbidden,
      originalError: originalError,
    );
  }

  /// 리소스 없음 (404)
  factory AppException.notFound({String? message, dynamic originalError}) {
    return AppException(
      message: message ?? '요청한 정보를 찾을 수 없습니다',
      type: AppExceptionType.notFound,
      originalError: originalError,
    );
  }

  /// 유효성 검증 에러 (400)
  factory AppException.validation({String? message, String? code, dynamic originalError}) {
    return AppException(
      message: message ?? '입력 정보를 확인해주세요',
      code: code,
      type: AppExceptionType.validation,
      originalError: originalError,
    );
  }

  /// 타임아웃 에러
  factory AppException.timeout({String? message, dynamic originalError}) {
    return AppException(
      message: message ?? '요청 시간이 초과되었습니다. 다시 시도해주세요',
      type: AppExceptionType.timeout,
      originalError: originalError,
    );
  }

  /// 취소된 요청
  factory AppException.cancelled({dynamic originalError}) {
    return AppException(
      message: '요청이 취소되었습니다',
      type: AppExceptionType.cancelled,
      originalError: originalError,
    );
  }

  /// 알 수 없는 에러
  factory AppException.unknown({String? message, dynamic originalError}) {
    return AppException(
      message: message ?? '오류가 발생했습니다. 다시 시도해주세요',
      type: AppExceptionType.unknown,
      originalError: originalError,
    );
  }

  @override
  String toString() => 'AppException: $message (type: $type, code: $code)';

  /// 재시도 가능한 에러인지 확인
  bool get isRetryable {
    return type == AppExceptionType.network ||
        type == AppExceptionType.timeout ||
        type == AppExceptionType.server;
  }

  /// 로그아웃이 필요한 에러인지 확인
  bool get requiresLogout {
    return type == AppExceptionType.unauthorized;
  }
}

/// 예외 타입 정의
enum AppExceptionType {
  network,      // 네트워크 연결 문제
  server,       // 서버 에러 (5xx)
  unauthorized, // 인증 필요 (401)
  forbidden,    // 권한 없음 (403)
  notFound,     // 리소스 없음 (404)
  validation,   // 유효성 검증 실패 (400)
  timeout,      // 타임아웃
  cancelled,    // 요청 취소
  unknown,      // 알 수 없는 에러
}
