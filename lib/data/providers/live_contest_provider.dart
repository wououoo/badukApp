import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_contest.dart';
import '../services/live_contest_service.dart';

/// LiveContestService 프로바이더
final liveContestServiceProvider =
    Provider<LiveContestService>((ref) => LiveContestService());

/// 라이브 대회 목록 프로바이더
final liveContestsProvider = FutureProvider<List<LiveContest>>((ref) async {
  final service = ref.watch(liveContestServiceProvider);
  return service.getLiveContests();
});

/// 라이브 대회 상세 프로바이더
final liveContestDetailProvider =
    FutureProvider.family<LiveContestDetail, int>((ref, contestId) async {
  final service = ref.watch(liveContestServiceProvider);
  return service.getLiveContestDetail(contestId);
});

/// 라이브 부문 상세 프로바이더
final liveSortDetailProvider =
    FutureProvider.family<LiveSortDetail, LiveSortParams>((ref, params) async {
  final service = ref.watch(liveContestServiceProvider);
  return service.getLiveSortDetail(params.contestId, params.sortId);
});

/// 순위표 프로바이더
final liveStandingsProvider =
    FutureProvider.family<List<LiveStanding>, LiveSortParams>(
        (ref, params) async {
  final service = ref.watch(liveContestServiceProvider);
  return service.getRankings(params.contestId, params.sortId);
});

/// 라이브 부문 파라미터
class LiveSortParams {
  final int contestId;
  final int sortId;

  const LiveSortParams({
    required this.contestId,
    required this.sortId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveSortParams &&
        other.contestId == contestId &&
        other.sortId == sortId;
  }

  @override
  int get hashCode => contestId.hashCode ^ sortId.hashCode;
}

/// 자동 새로고침을 위한 스트림 프로바이더 (선택적)
final liveContestRefreshProvider =
    StreamProvider.family<LiveSortDetail, LiveSortParams>((ref, params) async* {
  final service = ref.watch(liveContestServiceProvider);

  while (true) {
    try {
      yield await service.getLiveSortDetail(params.contestId, params.sortId);
    } catch (e) {
      // 에러 무시하고 계속 시도
    }
    await Future.delayed(const Duration(seconds: 30)); // 30초마다 새로고침
  }
});
