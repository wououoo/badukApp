import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/contest_photo.dart';

/// 대회 사진 전체화면 뷰어
class ContestPhotoViewScreen extends StatelessWidget {
  final ContestPhoto photo;

  const ContestPhotoViewScreen({
    super.key,
    required this.photo,
  });

  String _buildImageUrl(String photoUrl) {
    return '${ApiConstants.baseUrl.replaceAll('/api', '')}$photoUrl';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  _buildImageUrl(photo.photoUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            color: Colors.black87,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      photo.uploaderName ?? '매니저',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(photo.createdAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                if (photo.caption != null && photo.caption!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    photo.caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
