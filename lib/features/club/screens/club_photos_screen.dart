import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club_photo.dart';
import '../../../data/services/club_service.dart';

class ClubPhotosScreen extends StatefulWidget {
  final int clubId;
  final String? myRole;

  const ClubPhotosScreen({super.key, required this.clubId, this.myRole});

  @override
  State<ClubPhotosScreen> createState() => ClubPhotosScreenState();
}

class ClubPhotosScreenState extends State<ClubPhotosScreen> with AutomaticKeepAliveClientMixin {
  final ClubService _clubService = ClubService();
  final List<ClubPhoto> _photos = [];
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
      final result = await _clubService.getClubPhotos(widget.clubId, page: 0, size: 30);
      final photos = result['photos'] as List<ClubPhoto>;
      setState(() {
        _photos.addAll(photos);
        _hasNext = result['hasNext'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasNext) return;
    setState(() => _isLoading = true);
    try {
      final nextPage = _page + 1;
      final result = await _clubService.getClubPhotos(widget.clubId, page: nextPage, size: 30);
      final photos = result['photos'] as List<ClubPhoto>;
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

  void refresh() {
    _loadPhotos();
  }

  Future<void> _deletePhoto(ClubPhoto photo, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _clubService.deleteClubPhotoItem(widget.clubId, photo.id);
      setState(() => _photos.removeAt(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('[Error] 사진 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
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
            SizedBox(height: 120),
            Center(
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined, size: 48, color: AppColors.textTertiary),
                  SizedBox(height: 12),
                  Text('아직 사진이 없습니다', style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
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
                '/clubs/${widget.clubId}/photos/${photo.id}',
                extra: {
                  'photo': photo,
                  'canDelete': widget.myRole == 'OWNER' || widget.myRole == 'ADMIN',
                },
              ).then((result) {
                if (result == true) _loadPhotos();
              });
            },
            onLongPress: () => _deletePhoto(photo, index),
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
