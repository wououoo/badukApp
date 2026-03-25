import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';

/// AI 계가 결과
class BoardAnalysisResult {
  final int blackCount;
  final int whiteCount;
  final List<List<String>> stones;
  final double blackScore;
  final double whiteScore;
  final double scoreLead;
  final int blackTerritory;
  final int whiteTerritory;
  final String nextColor;
  final String rules;
  final List<double>? ownership;

  BoardAnalysisResult({
    required this.blackCount,
    required this.whiteCount,
    required this.stones,
    required this.blackScore,
    required this.whiteScore,
    required this.scoreLead,
    required this.blackTerritory,
    required this.whiteTerritory,
    required this.nextColor,
    required this.rules,
    this.ownership,
  });

  factory BoardAnalysisResult.fromJson(Map<String, dynamic> json) {
    return BoardAnalysisResult(
      blackCount: json['blackCount'] ?? 0,
      whiteCount: json['whiteCount'] ?? 0,
      stones: (json['stones'] as List?)
              ?.map((s) => (s as List).map((e) => e.toString()).toList())
              .toList() ??
          [],
      blackScore: (json['blackScore'] as num?)?.toDouble() ?? 0.0,
      whiteScore: (json['whiteScore'] as num?)?.toDouble() ?? 0.0,
      scoreLead: (json['scoreLead'] as num?)?.toDouble() ?? 0.0,
      blackTerritory: json['blackTerritory'] ?? 0,
      whiteTerritory: json['whiteTerritory'] ?? 0,
      nextColor: json['nextColor'] ?? 'B',
      rules: json['rules'] ?? 'chinese',
      ownership: (json['ownership'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  /// 결과 텍스트 (예: "흑 3.5집 승" 또는 "백 2.5집 승")
  String get resultText {
    if (scoreLead > 0) {
      return '흑 ${scoreLead.toStringAsFixed(1)}집 승';
    } else if (scoreLead < 0) {
      return '백 ${(-scoreLead).toStringAsFixed(1)}집 승';
    }
    return '빅';
  }

  bool get blackWins => scoreLead > 0;
}

/// AI 서버에 바둑판 사진을 보내 계가하는 서비스
class BoardAnalysisService {
  static final BoardAnalysisService _instance = BoardAnalysisService._();
  static BoardAnalysisService get instance => _instance;

  late final Dio _dio;

  BoardAnalysisService._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.aiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'X-Board-Api-Key': ApiConstants.boardApiKey,
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: true,
        logPrint: (obj) => debugPrint('[BoardAI] $obj'),
      ));
    }
  }

  /// 바둑판 사진 계가
  Future<BoardAnalysisResult> analyzeBoard({
    required File imageFile,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'board.jpg',
      ),
      'nextColor': 'B',
    });

    final response = await _dio.post(
      ApiConstants.boardAnalyze,
      data: formData,
    );

    return BoardAnalysisResult.fromJson(response.data);
  }
}
