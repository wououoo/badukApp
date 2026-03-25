import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment.dart';
import '../services/payment_service.dart';

/// PaymentService 프로바이더
final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());

/// 결제 상태 관리 (StateNotifier)
class PaymentState {
  final Payment? currentPayment;
  final bool isLoading;
  final String? errorMessage;

  PaymentState({
    this.currentPayment,
    this.isLoading = false,
    this.errorMessage,
  });

  PaymentState copyWith({
    Payment? currentPayment,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PaymentState(
      currentPayment: currentPayment ?? this.currentPayment,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentService _service;

  PaymentNotifier(this._service) : super(PaymentState());

  /// 결제 준비
  Future<Payment?> preparePayment({
    required int registrationId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final payment = await _service.preparePayment(
        registrationId: registrationId,
      );
      state = state.copyWith(currentPayment: payment, isLoading: false);
      return payment;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  /// 결제 확인
  Future<Payment?> confirmPayment({
    required String paymentKey,
    required String orderId,
    required int amount,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final payment = await _service.confirmPayment(
        paymentKey: paymentKey,
        orderId: orderId,
        amount: amount,
      );
      state = state.copyWith(currentPayment: payment, isLoading: false);
      return payment;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  /// 결제 상태 조회
  Future<void> loadPayment(int registrationId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final payment = await _service.getPayment(registrationId);
      state = state.copyWith(currentPayment: payment, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// 상태 초기화
  void reset() {
    state = PaymentState();
  }
}

/// 결제 상태 프로바이더
final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  final service = ref.watch(paymentServiceProvider);
  return PaymentNotifier(service);
});

/// 결제 정보 조회 프로바이더 (Family)
final paymentByRegistrationProvider = FutureProvider.family<Payment, int>((ref, registrationId) async {
  final service = ref.watch(paymentServiceProvider);
  return service.getPayment(registrationId);
});

/// 환불 금액 계산 프로바이더 (Family)
final refundCalculationProvider = FutureProvider.family<RefundCalculation, int>((ref, registrationId) async {
  final service = ref.watch(paymentServiceProvider);
  return service.calculateRefund(registrationId);
});

/// 환불 내역 프로바이더 (Family)
final refundHistoryProvider = FutureProvider.family<List<Refund>, int>((ref, registrationId) async {
  final service = ref.watch(paymentServiceProvider);
  return service.getRefundHistory(registrationId);
});

/// 환불 정책 프로바이더 (Family)
final refundPoliciesProvider = FutureProvider.family<List<RefundPolicy>, int?>((ref, homepageId) async {
  final service = ref.watch(paymentServiceProvider);
  return service.getRefundPolicies(homepageId: homepageId);
});
