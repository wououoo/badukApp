import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';
import '../../core/error/error_handler.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final _AuthInterceptor _authInterceptor;

  static final ApiClient _instance = ApiClient._internal();
  static ApiClient get instance => _instance;
  factory ApiClient() => _instance;

  // 로그아웃 콜백 (인증 만료 시 호출)
  static VoidCallback? onUnauthorized;

  // 업데이트 필요 콜백 (426 응답 시 호출)
  static VoidCallback? onUpdateRequired;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      contentType: 'application/json',
      headers: {
        'Accept': 'application/json',
      },
    ));

    // 인터셉터 순서: 인증(+빌드번호) -> 에러 -> 로그
    _authInterceptor = _AuthInterceptor(_storage);
    _dio.interceptors.add(_authInterceptor);
    _dio.interceptors.add(_ErrorInterceptor());

    // 디버그 모드에서만 로그 출력
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[API] $obj'),
      ));
    }
  }

  Dio get dio => _dio;

  /// 토큰 메모리 캐시 갱신 (로그인 성공 시 호출)
  void updateCachedToken(String? token) {
    _authInterceptor.updateToken(token);
  }

  /// GET 요청
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  /// POST 요청
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters);
  }

  /// PUT 요청
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.put<T>(path, data: data, queryParameters: queryParameters);
  }

  /// DELETE 요청
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.delete<T>(path, data: data, queryParameters: queryParameters);
  }

  /// 안전한 API 호출 래퍼
  /// 에러를 AppException으로 변환하여 처리
  Future<T> safeCall<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw ErrorHandler.handleDioError(e);
    } catch (e) {
      throw ErrorHandler.handleError(e);
    }
  }
}

/// 인증 인터셉터 (401 시 토큰 자동 갱신)
/// QueuedInterceptor: async onRequest에서 토큰 읽기가 완료될 때까지
/// 다음 요청이 대기하므로 동시 요청 시 토큰 누락 방지
class _AuthInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;
  final List<_RetryEntry> _pendingRequests = [];

  // 토큰 메모리 캐시 (storage 읽기 실패 방지)
  String? _cachedToken;

  // 빌드번호 캐시 (한 번만 조회)
  String? _cachedBuildNumber;

  _AuthInterceptor(this._storage);

  /// 토큰 설정 (로그인 성공 시 외부에서 호출)
  void updateToken(String? token) {
    _cachedToken = token;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 빌드번호 + 플랫폼 헤더 추가 (웹이 아닌 경우에만)
    if (!kIsWeb) {
      if (_cachedBuildNumber == null) {
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          _cachedBuildNumber = packageInfo.buildNumber;
        } catch (_) {}
      }
      if (_cachedBuildNumber != null) {
        options.headers['X-App-Build'] = _cachedBuildNumber;
      }
      // 플랫폼 구분 헤더 (Android/iOS 별도 버전 관리용)
      try {
        if (Platform.isIOS) {
          options.headers['X-App-Platform'] = 'ios';
        } else if (Platform.isAndroid) {
          options.headers['X-App-Platform'] = 'android';
        }
      } catch (_) {}
    }

    // 토큰이 필요 없는 API (로그인/회원가입/OTP 등)
    final noAuthPaths = [
      ApiConstants.login,
      ApiConstants.register,
      ApiConstants.otpSend,
      ApiConstants.otpVerify,
      ApiConstants.appConfig,
    ];

    if (!noAuthPaths.any((path) => options.path.contains(path))) {
      // 메모리 캐시 우선, 없으면 storage에서 읽기
      String? token = _cachedToken;
      if (token == null) {
        token = await _storage.read(key: AppConstants.accessTokenKey);
        if (token != null) {
          _cachedToken = token; // 캐시에 저장
        }
      }
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      } else if (kDebugMode) {
        debugPrint('[Auth] 토큰 없음');
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // refresh 엔드포인트 자체의 401은 즉시 로그아웃 (무한루프 방지)
      if (err.requestOptions.path.contains(ApiConstants.mobileRefresh)) {
        await _clearTokensAndLogout();
        handler.next(err);
        return;
      }

      if (!_isRefreshing) {
        _isRefreshing = true;
        bool refreshed = false;

        try {
          // refreshToken만 사용 (access token으로 fallback 금지 — 보안상 분리 의미 유지)
          final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
          if (refreshToken == null || refreshToken.isEmpty) {
            // refresh 토큰이 없으면 갱신 불가 → 즉시 로그아웃
            if (kDebugMode) debugPrint('[Auth] refreshToken 없음 → 로그아웃');
            await _clearTokensAndLogout();
          } else {
            // 별도 Dio 인스턴스로 refresh 요청 (인터셉터 무한루프 방지)
            final refreshDio = Dio(BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: ApiConstants.connectTimeout,
              receiveTimeout: ApiConstants.receiveTimeout,
            ));

            final response = await refreshDio.post(
              ApiConstants.mobileRefresh,
              options: Options(
                headers: {'Authorization': 'Bearer $refreshToken'},
              ),
            );

            final newAccessToken = (response.data['accessToken'] ?? response.data['token']) as String?;
            final newRefreshToken = response.data['refreshToken'] as String?;

            if (newAccessToken != null) {
              await _storage.write(key: AppConstants.accessTokenKey, value: newAccessToken);
              _cachedToken = newAccessToken; // 메모리 캐시 갱신
              if (newRefreshToken != null) {
                await _storage.write(key: AppConstants.refreshTokenKey, value: newRefreshToken);
              }

              // 원래 요청 재시도
              err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              final retryResponse = await refreshDio.fetch(err.requestOptions);
              handler.resolve(retryResponse);
              refreshed = true;

              // 대기 중인 요청들도 재시도
              for (final entry in _pendingRequests) {
                entry.options.headers['Authorization'] = 'Bearer $newAccessToken';
                try {
                  final r = await refreshDio.fetch(entry.options);
                  entry.handler.resolve(r);
                } catch (e) {
                  entry.handler.next(DioException(
                    requestOptions: entry.options,
                    error: e,
                  ));
                }
              }
              _pendingRequests.clear();
            } else {
              // 응답에 토큰이 없으면 갱신 실패 → 로그아웃
              if (kDebugMode) debugPrint('[Auth] refresh 응답에 토큰 없음 → 로그아웃');
              await _clearTokensAndLogout();
            }
          }
        } catch (e) {
          // 갱신 실패 (네트워크 에러, refreshToken 만료/무효 등) → 명확히 로그아웃
          // 이전 동작(토큰 보존)은 무한 401 루프 유발했으므로 제거
          if (kDebugMode) debugPrint('[Auth] Token refresh failed: $e');
          await _clearTokensAndLogout();
        } finally {
          _isRefreshing = false;
        }

        if (!refreshed) {
          // 대기 중인 요청들 모두 실패 처리
          for (final entry in _pendingRequests) {
            entry.handler.next(DioException(
              requestOptions: entry.options,
              error: 'Token refresh failed',
            ));
          }
          _pendingRequests.clear();
        }
      } else {
        // 이미 refresh 중이면 대기열에 추가
        _pendingRequests.add(_RetryEntry(err.requestOptions, handler));
        return;
      }
    }
    handler.next(err);
  }

  Future<void> _clearTokensAndLogout() async {
    _cachedToken = null; // 메모리 캐시 초기화
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    ApiClient.onUnauthorized?.call();
  }
}

/// 토큰 갱신 대기열 엔트리
class _RetryEntry {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _RetryEntry(this.options, this.handler);
}

/// 에러 인터셉터
/// DioException을 AppException으로 변환하고 전역 처리
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 426 Upgrade Required → 업데이트 필요
    if (err.response?.statusCode == 426) {
      ApiClient.onUpdateRequired?.call();
      handler.next(err);
      return;
    }

    final appException = ErrorHandler.handleDioError(err);

    // 에러 로깅
    ErrorHandler.logError(err);

    // 에러 스낵바는 표시하지 않음 (각 화면에서 개별 처리)
    // 로그만 남김

    // DioException에 AppException 정보 포함하여 전달
    final newError = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: appException,
    );

    handler.next(newError);
  }
}
