import 'portal_participant.dart';

/// 참가자 검색 결과 모델
class SearchResult {
  final bool found;
  final bool multipleResults;
  final String? message;
  final PortalParticipant? participant;
  final List<PortalParticipant> participants;

  SearchResult({
    required this.found,
    this.multipleResults = false,
    this.message,
    this.participant,
    this.participants = const [],
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final participantsList = json['participants'] != null
        ? (json['participants'] as List)
            .map((e) => PortalParticipant.fromJson(e))
            .toList()
        : <PortalParticipant>[];

    return SearchResult(
      found: json['found'] ?? false,
      multipleResults: json['multipleResults'] ?? false,
      message: json['message'],
      participant: json['participant'] != null
          ? PortalParticipant.fromJson(json['participant'])
          : null,
      participants: participantsList,
    );
  }

  /// 검색 결과 없음
  factory SearchResult.notFound({String? message}) {
    return SearchResult(
      found: false,
      message: message ?? '검색 결과가 없습니다.',
    );
  }
}
