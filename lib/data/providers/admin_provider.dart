import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

/// 주최자 신청 모델
class HostApplication {
  final int id;
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? organization;
  final String? organizationType;
  final String? reason;
  final String? hostStatus;
  final String? appliedAt;

  HostApplication({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.email,
    this.organization,
    this.organizationType,
    this.reason,
    this.hostStatus,
    this.appliedAt,
  });

  factory HostApplication.fromJson(Map<String, dynamic> json) {
    return HostApplication(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      organization: json['organization'],
      organizationType: json['organizationType'],
      reason: json['hostApplicationReason'],
      hostStatus: json['hostStatus'],
      appliedAt: json['hostAppliedAt'],
    );
  }
}

/// 주최자 신청 목록 Provider
final hostApplicationsProvider = FutureProvider<List<HostApplication>>((ref) async {
  final apiClient = ApiClient.instance;

  final response = await apiClient.get(
    '/mobile/users/admin/host-applications',
    queryParameters: {'status': 'PENDING'},
  );

  final content = response.data['content'] as List<dynamic>? ?? [];
  return content.map((e) => HostApplication.fromJson(e)).toList();
});

/// 관리자 액션 Provider
class AdminActionsNotifier extends StateNotifier<AsyncValue<void>> {
  AdminActionsNotifier() : super(const AsyncValue.data(null));

  final _apiClient = ApiClient.instance;

  /// 주최자 승인
  Future<void> approveHost(int userId) async {
    state = const AsyncValue.loading();
    try {
      await _apiClient.post(
        '/mobile/users/admin/host-applications/$userId/approve',
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// 주최자 거절
  Future<void> rejectHost(int userId, String? reason) async {
    state = const AsyncValue.loading();
    try {
      await _apiClient.post(
        '/mobile/users/admin/host-applications/$userId/reject',
        data: {'reason': reason ?? ''},
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// 주최자 권한 회수
  Future<void> revokeHost(int userId) async {
    state = const AsyncValue.loading();
    try {
      await _apiClient.post(
        '/mobile/users/admin/hosts/$userId/revoke',
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final adminActionsProvider = StateNotifierProvider<AdminActionsNotifier, AsyncValue<void>>((ref) {
  return AdminActionsNotifier();
});
