import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

/// 주최자 신청 상태
class HostApplyState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  HostApplyState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  HostApplyState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return HostApplyState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// 주최자 신청 Notifier
class HostApplyNotifier extends StateNotifier<HostApplyState> {
  HostApplyNotifier() : super(HostApplyState());

  final _apiClient = ApiClient.instance;

  /// 주최자 신청
  Future<void> applyForHost({
    required String organization,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _apiClient.post(
        '/mobile/users/me/host-application',
        data: {
          'organization': organization,
          'reason': reason,
        },
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// 상태 초기화
  void reset() {
    state = HostApplyState();
  }
}

final hostApplyProvider = StateNotifierProvider<HostApplyNotifier, HostApplyState>((ref) {
  return HostApplyNotifier();
});

/// 주최자 상태 조회
final hostStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiClient = ApiClient.instance;
  final response = await apiClient.get('/mobile/users/me/host-status');
  return response.data;
});
