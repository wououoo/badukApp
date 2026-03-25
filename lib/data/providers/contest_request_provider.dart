import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/create_contest_model.dart';

/// 대회 개최 의뢰 상태
class ContestRequestState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final int currentStep;
  final ContestRequestInput input;
  final int? requestId;

  ContestRequestState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.currentStep = 0,
    ContestRequestInput? input,
    this.requestId,
  }) : input = input ?? ContestRequestInput();

  ContestRequestState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    int? currentStep,
    ContestRequestInput? input,
    int? requestId,
  }) {
    return ContestRequestState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      currentStep: currentStep ?? this.currentStep,
      input: input ?? this.input,
      requestId: requestId ?? this.requestId,
    );
  }
}

/// 대회 개최 의뢰 Notifier
class ContestRequestNotifier extends StateNotifier<ContestRequestState> {
  ContestRequestNotifier() : super(ContestRequestState());

  final _apiClient = ApiClient.instance;

  /// 다음 단계로 이동
  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  /// 이전 단계로 이동
  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  /// 특정 단계로 이동
  void goToStep(int step) {
    if (step >= 0 && step <= 2) {
      state = state.copyWith(currentStep: step);
    }
  }

  /// 기본 정보 업데이트
  void updateBasicInfo({
    String? title,
    String? subtitle,
    String? organizer,
    String? sponsor,
    String? eligibility,
    String? participationFee,
    String? schedule,
    String? venue,
    String? registrationPeriod,
    DateTime? registrationStartDate,
    DateTime? registrationEndDate,
    String? contactInfo,
    String? additionalNotes,
  }) {
    final input = state.input;
    if (title != null) input.title = title;
    if (subtitle != null) input.subtitle = subtitle;
    if (organizer != null) input.organizer = organizer;
    if (sponsor != null) input.sponsor = sponsor;
    if (eligibility != null) input.eligibility = eligibility;
    if (participationFee != null) input.participationFee = participationFee;
    if (schedule != null) input.schedule = schedule;
    if (venue != null) input.venue = venue;
    if (registrationPeriod != null) input.registrationPeriod = registrationPeriod;
    if (registrationStartDate != null) input.registrationStartDate = registrationStartDate;
    if (registrationEndDate != null) input.registrationEndDate = registrationEndDate;
    if (contactInfo != null) input.contactInfo = contactInfo;
    if (additionalNotes != null) input.additionalNotes = additionalNotes;

    state = state.copyWith(input: input);
  }

  /// 부문 추가
  void addCategory(ContestCategoryInput category) {
    final input = state.input;
    input.categories.add(category);
    state = state.copyWith(input: input);
  }

  /// 부문 수정
  void updateCategory(int index, ContestCategoryInput category) {
    final input = state.input;
    if (index >= 0 && index < input.categories.length) {
      input.categories[index] = category;
      state = state.copyWith(input: input);
    }
  }

  /// 부문 삭제
  void removeCategory(int index) {
    final input = state.input;
    if (index >= 0 && index < input.categories.length) {
      input.categories.removeAt(index);
      state = state.copyWith(input: input);
    }
  }

  /// 첨부파일 추가
  void addAttachment(String path) {
    final input = state.input;
    input.attachmentPaths.add(path);
    state = state.copyWith(input: input);
  }

  /// 첨부파일 삭제
  void removeAttachment(int index) {
    final input = state.input;
    if (index >= 0 && index < input.attachmentPaths.length) {
      input.attachmentPaths.removeAt(index);
      state = state.copyWith(input: input);
    }
  }

  /// 대회 개최 의뢰 제출
  Future<void> submitRequest() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1. 의뢰 정보 전송
      final response = await _apiClient.post(
        '/mobile/host/contest-requests',
        data: state.input.toJson(),
      );

      final requestId = response.data['requestId'] as int;

      // 2. 첨부파일 업로드
      if (state.input.attachmentPaths.isNotEmpty) {
        await _uploadAttachments(requestId);
      }

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        requestId: requestId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// 첨부파일 업로드
  Future<void> _uploadAttachments(int requestId) async {
    for (final path in state.input.attachmentPaths) {
      final file = File(path);
      if (await file.exists()) {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            path,
            filename: path.split('/').last.split('\\').last,
          ),
        });

        await _apiClient.post(
          '/mobile/host/contest-requests/$requestId/files',
          data: formData,
        );
      }
    }
  }

  /// 로딩 상태 설정
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// 단일 파일 업로드 (수정 모드에서 사용) - path 방식 (모바일)
  Future<void> uploadFile(int requestId, String path) async {
    final file = File(path);
    if (await file.exists()) {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          path,
          filename: path.split('/').last.split('\\').last,
        ),
      });

      await _apiClient.post(
        '/mobile/host/contest-requests/$requestId/files',
        data: formData,
      );
    }
  }

  /// 단일 파일 업로드 (bytes 방식 - 웹 지원)
  Future<void> uploadFileBytes(int requestId, String filename, List<int> bytes) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
    });

    await _apiClient.post(
      '/mobile/host/contest-requests/$requestId/files',
      data: formData,
    );
  }

  /// 상태 초기화
  void reset() {
    state = ContestRequestState();
  }
}

final contestRequestProvider =
    StateNotifierProvider<ContestRequestNotifier, ContestRequestState>((ref) {
  return ContestRequestNotifier();
});

/// 내 의뢰 목록 조회
final myContestRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiClient = ApiClient.instance;
  final response = await apiClient.get('/mobile/host/contest-requests');
  return List<Map<String, dynamic>>.from(response.data['requests'] ?? []);
});
