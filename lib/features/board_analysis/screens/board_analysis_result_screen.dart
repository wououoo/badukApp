import 'dart:io';
import 'package:flutter/material.dart';
import '../../../data/services/board_analysis_service.dart';
import '../widgets/ownership_board_widget.dart';

/// AI 계가 결과 화면
class BoardAnalysisResultScreen extends StatefulWidget {
  final File imageFile;

  const BoardAnalysisResultScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<BoardAnalysisResultScreen> createState() =>
      _BoardAnalysisResultScreenState();
}

class _BoardAnalysisResultScreenState extends State<BoardAnalysisResultScreen> {
  BoardAnalysisResult? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final result = await BoardAnalysisService.instance.analyzeBoard(
        imageFile: widget.imageFile,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('계가 결과'),
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildResult(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF2D2D2D)),
          SizedBox(height: 24),
          Text('AI가 집을 계산하고 있습니다...', style: TextStyle(fontSize: 16)),
          SizedBox(height: 8),
          Text('최대 30초 소요될 수 있습니다',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text('계가에 실패했습니다',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _analyze();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 승패 결과 카드
          _buildResultCard(result),

          const SizedBox(height: 16),

          // 계가 상세
          _buildScoringDetail(result),

          const SizedBox(height: 16),

          // 돌 수 정보
          _buildStoneInfo(result),

          const SizedBox(height: 16),

          // 규칙 정보
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '중국룰 · 덤 6.5집',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),

          const SizedBox(height: 20),

          // 계가 시각화 (바둑판 + ownership)
          const Text('영역 표시',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '검정 사각형 = 흑 집 · 흰 사각형 = 백 집',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          OwnershipBoardWidget(result: result),

          const SizedBox(height: 20),

          // 원본 사진
          const Text('촬영 사진',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              widget.imageFile,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 승패 결과 카드
  Widget _buildResultCard(BoardAnalysisResult result) {
    final blackWins = result.blackWins;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: blackWins
              ? [const Color(0xFF2D2D2D), const Color(0xFF404040)]
              : [Colors.grey.shade100, Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 승패 결과
          Text(
            result.resultText,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: blackWins ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          // 점수 비교 바
          Row(
            children: [
              Text(
                '흑 ${result.blackScore.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: blackWins ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.blackScore + result.whiteScore > 0
                        ? result.blackScore /
                            (result.blackScore + result.whiteScore)
                        : 0.5,
                    minHeight: 12,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation(Colors.black),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '백 ${result.whiteScore.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: blackWins ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 계가 상세 (집 수)
  Widget _buildScoringDetail(BoardAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('계가 상세',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildScoreRow('흑 집 (빈 영역)', '${result.blackTerritory}'),
          _buildScoreRow('흑 돌 수', '${result.blackCount}'),
          const Divider(height: 16),
          _buildScoreRow('흑 총점', result.blackScore.toStringAsFixed(0),
              bold: true),
          const SizedBox(height: 12),
          _buildScoreRow('백 집 (빈 영역)', '${result.whiteTerritory}'),
          _buildScoreRow('백 돌 수', '${result.whiteCount}'),
          _buildScoreRow('덤', '6.5'),
          const Divider(height: 16),
          _buildScoreRow('백 총점', result.whiteScore.toStringAsFixed(1),
              bold: true),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? Colors.black : Colors.grey.shade700,
              )),
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              )),
        ],
      ),
    );
  }

  /// 돌 수 정보
  Widget _buildStoneInfo(BoardAnalysisResult result) {
    return Row(
      children: [
        Expanded(
            child: _buildStoneChip(
                '흑 ${result.blackCount}개', Colors.black, Colors.white)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStoneChip(
                '백 ${result.whiteCount}개', Colors.white, Colors.black)),
      ],
    );
  }

  Widget _buildStoneChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: fg, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
