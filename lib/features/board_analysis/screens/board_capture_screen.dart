import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'board_analysis_result_screen.dart';

/// 바둑판 사진 촬영/선택 화면
class BoardCaptureScreen extends StatelessWidget {
  const BoardCaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 계가'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // 안내 아이콘
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.grid_on,
                  size: 64,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '바둑판 사진으로 AI 계가',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '바둑판을 정면에서 촬영하면\nAI가 흑백 집수를 계산합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // 안내 사항
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTip('중국룰(덤 6.5집)로 계산됩니다'),
                    const SizedBox(height: 6),
                    _buildTip('끝난 대국을 찍으면 더 정확합니다'),
                    const SizedBox(height: 6),
                    _buildTip('정면에서 찍을수록 더 정확합니다'),
                  ],
                ),
              ),
              const Spacer(),
              // 카메라 촬영 버튼
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(context, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('카메라로 촬영', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2D2D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 갤러리 선택 버튼
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리에서 선택', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D2D2D),
                    side: const BorderSide(color: Color(0xFF2D2D2D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.amber.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );

    if (picked != null && context.mounted) {
      // 사진 찍으면 바로 계가 화면으로
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BoardAnalysisResultScreen(
            imageFile: File(picked.path),
          ),
        ),
      );
    }
  }
}
