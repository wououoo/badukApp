import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/host_operation.dart';
import '../services/host_operation_service.dart';

/// 주최자 운영 서비스 프로바이더
final hostOperationServiceProvider = Provider<HostOperationService>((ref) {
  return HostOperationService();
});

/// A1 — 내가 운영할 대회 목록
final hostContestsProvider =
    FutureProvider.autoDispose<List<HostContest>>((ref) async {
  return ref.watch(hostOperationServiceProvider).getMyContests();
});

/// A2 — 대회의 부문 목록 (homepageId별)
final contestSectionsProvider = FutureProvider.autoDispose
    .family<List<ContestSection>, int>((ref, homepageId) async {
  return ref.watch(hostOperationServiceProvider).getSections(homepageId);
});

/// B — MCM 부문 운영 현황 (matches/players/rankings 원본 Map)
/// key: (homepageId, gameRoomId, round). round=null 이면 서버가 현재 라운드를 반환.
/// 라운드 칩으로 과거 라운드를 보려면 round 를 키에 넣어 각 라운드를 따로 조회해야 한다.
final mcmahonSectionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>,
        ({int homepageId, int gameRoomId, int? round})>((ref, key) async {
  return ref
      .watch(hostOperationServiceProvider)
      .getMcmahon(key.homepageId, key.gameRoomId, round: key.round);
});

/// B — 스위스 부문 운영 현황 (roundResult/rankings 원본 Map)
/// key 에 round 포함 — 과거 라운드 조회용(null=현재).
final swissSectionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>,
        ({int homepageId, int gameRoomId, int? round})>((ref, key) async {
  return ref
      .watch(hostOperationServiceProvider)
      .getSwiss(key.homepageId, key.gameRoomId, round: key.round);
});

/// B — 단체 스위스 부문 운영 현황 (팀매치·장별 + rankings)
/// key 에 round 포함 — 과거 라운드 조회용(null=현재).
final teamSwissSectionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>,
        ({int homepageId, int gameRoomId, int? round})>((ref, key) async {
  return ref
      .watch(hostOperationServiceProvider)
      .getTeamSwiss(key.homepageId, key.gameRoomId, round: key.round);
});

/// B — 풀리그 부문 운영 현황 (roundResult/rankings)
final fullLeagueSectionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({int homepageId, int gameRoomId})>(
        (ref, key) async {
  return ref
      .watch(hostOperationServiceProvider)
      .getFullLeague(key.homepageId, key.gameRoomId);
});

/// B — 단체 풀리그 부문 운영 현황 (팀매치·장별 + rankings)
final teamFullLeagueSectionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({int homepageId, int gameRoomId})>(
        (ref, key) async {
  return ref
      .watch(hostOperationServiceProvider)
      .getTeamFullLeague(key.homepageId, key.gameRoomId);
});

/// B — 싱글 토너먼트 부문 운영 현황 (브래킷 + rankings)
final tournamentSectionProvider = FutureProvider.autoDispose
    .family<TournamentSection, ({int homepageId, int gameRoomId})>(
        (ref, key) async {
  return ref
      .watch(hostOperationServiceProvider)
      .getTournament(key.homepageId, key.gameRoomId);
});

/// B — DE 예선 현황 (조별 라운드 매치)
final dePrelimProvider = FutureProvider.autoDispose
    .family<DePrelimSection, ({int homepageId, int gameRoomId})>(
        (ref, key) async {
  return ref
      .watch(hostOperationServiceProvider)
      .getDePrelim(key.homepageId, key.gameRoomId);
});

/// B — DE 본선 현황 (full-bracket)
final deBracketProvider = FutureProvider.autoDispose
    .family<DeBracketSection, ({int homepageId, int gameRoomId})>(
        (ref, key) async {
  return ref
      .watch(hostOperationServiceProvider)
      .getDeBracket(key.homepageId, key.gameRoomId);
});
