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

  /// 토스 결제 준비 (주문번호 생성)
  /// POST /api/payment/prepare
  Future<Payment> preparePayment({
    required int registrationId,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.payment}/prepare',
      data: {
        'registrationId': registrationId,
        'paymentMethod': 'TOSS',
      },
    );

    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return Payment.fromJson(data['data']);
    }
    throw AppException.server(message: data['message'] ?? '결제 준비에 실패했습니다');
  }

  /// 결제 확인 (토스페이먼츠 결제 완료 후)
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

  /// 환불 신청 (토스 카드결제 즉시 환불)
  /// POST /api/refund/request
  Future<Refund> requestRefund({
    required int registrationId,
    String? refundReason,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.refund}/request',
      data: {
        'registrationId': registrationId,
        if (refundReason != null) 'refundReason': refundReason,
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
}
