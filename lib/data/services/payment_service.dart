import 'dart:convert';
import '../api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/error/app_exception.dart';
import '../models/payment.dart';
/// 결제 서비스
/// - 토스 결제 준비, 확인
/// - 환불 신청 및 조회
class PaymentService {
  final ApiClient _apiClient;

  PaymentService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ========== 결제 관련 ==========

  /// 결제 준비 (주문번호 생성)
  /// POST /api/payment/prepare
  /// - registrationId: 기존 미결제 재시도용
  /// - registrationData: 신규 결제용 (Registration 미생성, confirm 시 생성)
  Future<Payment> preparePayment({
    int? registrationId,
    Map<String, dynamic>? registrationData,
    required int homepageId,
    required int categoryId,
    required String participantName,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.payment}/prepare',
      data: {
        if (registrationId != null) 'registrationId': registrationId,
        'homepageId': homepageId,
        'categoryId': categoryId,
        'participantName': participantName,
        'paymentMethod': 'TOSS',
        if (registrationData != null) 'registrationJson': registrationData is String
            ? registrationData
            : _jsonEncode(registrationData),
      },
    );

    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return Payment.fromJson(data['data']);
    }
    throw AppException.server(message: data['message'] ?? '결제 준비에 실패했습니다');
  }

  /// 토스 결제 확인
  /// POST /api/payment/confirm
  Future<Payment> confirmPayment({
    required String paymentKey,
    required String orderId,
    required int amount,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.payment}/confirm',
      data: {
        'paymentKey': paymentKey,
        'orderId': orderId,
        'amount': amount,
      },
    );

    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return Payment.fromJson(data['data']);
    }
    throw AppException.server(message: data['message'] ?? '결제 확인에 실패했습니다');
  }

  /// 결제 상태 조회 - orderId 기반 (결제 복구용)
  /// GET /api/payment/order/{orderId}
  Future<Payment?> getPaymentByOrderId(String orderId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.payment}/order/$orderId',
      );
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        return Payment.fromJson(data['data']);
      }
    } catch (_) {
      // 조회 실패는 null 반환 (복구 시도라 throw 안 함)
    }
    return null;
  }

  /// 결제 상태 조회
  /// GET /api/payment/{registrationId}
  Future<Payment> getPayment(int registrationId) async {
    final response = await _apiClient.get(
      '${ApiConstants.payment}/$registrationId',
    );

    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return Payment.fromJson(data['data']);
    }
    throw AppException.notFound(message: data['message'] ?? '결제 정보를 찾을 수 없습니다');
  }

  // ========== 환불 관련 ==========

  /// 환불 금액 계산
  /// GET /api/refund/calculate
  Future<RefundCalculation> calculateRefund(int registrationId) async {
    final response = await _apiClient.get(
      '${ApiConstants.refund}/calculate',
      queryParameters: {'registrationId': registrationId},
    );

    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return RefundCalculation.fromJson(data['data']);
    }
    throw AppException.server(message: data['message'] ?? '환불 금액 계산에 실패했습니다');
  }

  /// 환불 신청 (토스 가상계좌 환불 - 환불계좌 정보 필수)
  /// POST /api/refund/request
  Future<Refund> requestRefund({
    required int registrationId,
    String? refundReason,
    String? refundBankCode,
    String? refundBankName,
    String? refundAccountNumber,
    String? refundAccountHolder,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.refund}/request',
      data: {
        'registrationId': registrationId,
        if (refundReason != null) 'refundReason': refundReason,
        if (refundBankCode != null) 'refundBankCode': refundBankCode,
        if (refundBankName != null) 'refundBankName': refundBankName,
        if (refundAccountNumber != null) 'refundAccountNumber': refundAccountNumber,
        if (refundAccountHolder != null) 'refundAccountHolder': refundAccountHolder,
      },
    );

    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return Refund.fromJson(data['data']);
    }
    throw AppException.server(message: data['message'] ?? '환불 신청에 실패했습니다');
  }

  /// 환불 내역 조회
  /// GET /api/refund/registration/{registrationId}
  Future<List<Refund>> getRefundHistory(int registrationId) async {
    final response = await _apiClient.get(
      '${ApiConstants.refund}/registration/$registrationId',
    );

    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return (data['data'] as List)
          .map((e) => Refund.fromJson(e))
          .toList();
    }
    return [];
  }

  /// 환불 정책 조회
  /// GET /api/refund/policy
  Future<List<RefundPolicy>> getRefundPolicies({int? homepageId}) async {
    final response = await _apiClient.get(
      '${ApiConstants.refund}/policy',
      queryParameters: homepageId != null ? {'homepageId': homepageId} : null,
    );

    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return (data['data'] as List)
          .map((e) => RefundPolicy.fromJson(e))
          .toList();
    }
    return [];
  }

  /// GET /api/refund/registration-notice — 신청 시점 환불 안내(문구+계산식 모두 백엔드 생성)
  Future<Map<String, dynamic>> getRegistrationNotice({required int homepageId, required int baseFee}) async {
    final response = await _apiClient.get(
      '${ApiConstants.refund}/registration-notice',
      queryParameters: {'homepageId': homepageId, 'baseFee': baseFee},
    );
    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return <String, dynamic>{};
  }

  String _jsonEncode(Map<String, dynamic> data) {
    return jsonEncode(data);
  }
}
