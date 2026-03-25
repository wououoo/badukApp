import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/contest_photo.dart';
import '../../../data/services/contest_service.dart';

/// 대회 사진 탭 위젯
class ContestPhotosTab extends StatefulWidget {
  final int homepageId;

  const ContestPhotosTab({super.key, required this.homepageId});

  @override
  State<ContestPhotosTab> createState() => _ContestPhotosTabState();
}

class _ContestPhotosTabState extends State<ContestPhotosTab> with AutomaticKeepAliveClientMixin {
  final ContestService _contestService = ContestService();
  final List<ContestPhoto> _photos = [];
  bool _isLoading = false;
  bool _hasNext = true;
  int _page = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadPhotos() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _page = 0;
      _photos.clear();
    });
    try {
      final result = await _contestService.getContestPhotos(widget.homepageId, page: 0, size: 30);
      final photos = result['photos'] as List<ContestPhoto>;
      setState(() {
        _photos.addAll(photos);
        _hasNext = result['hasNext'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ContestPhotosTab] 사진 로드 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasNext) return;
    setState(() => _isLoading = true);
    try {
      final nextPage = _page + 1;
      final result = await _contestService.getContestPhotos(widget.homepageId, page: nextPage, size: 30);
      final photos = result['photos'] as List<ContestPhoto>;
      setState(() {
        _photos.addAll(photos);
        _hasNext = result['hasNext'] as bool;
        _page = nextPage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _buildImageUrl(String photoUrl) {
    return '${ApiConstants.baseUrl.replaceAll('/api', '')}$photoUrl';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _photos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_photos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPhotos,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined, size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('아직 대회 사진이 없습니다', style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPhotos,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: _photos.length + (_hasNext ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _photos.length) {
            return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
          }

          final photo = _photos[index];
          return GestureDetector(
            onTap: () {
              context.push(
                '/contest/${widget.homepageId}/photos/${photo.id}',
                extra: {'photo': photo},
              ).then((result) {
                if (result == true) _loadPhotos();
              });
            },
            child: Image.network(
              _buildImageUrl(photo.photoUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.background,
                child: Icon(Icons.broken_image, color: AppColors.textTertiary),
              ),
            ),
          );
        },
      ),
    );
  }
}
