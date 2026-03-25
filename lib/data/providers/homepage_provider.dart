import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/homepage.dart';
import '../services/homepage_service.dart';

/// HomepageService 프로바이더
final homepageServiceProvider = Provider<HomepageService>((ref) => HomepageService());

/// 공개된 홈페이지 목록 프로바이더
final publicHomepagesProvider = FutureProvider<List<ContestHomepage>>((ref) async {
  final service = ref.watch(homepageServiceProvider);
  return service.getPublicHomepages();
});

/// 홈페이지 상세 프로바이더 (Family)
final homepageDetailProvider = FutureProvider.family<HomepageDetail, int>((ref, homepageId) async {
  final service = ref.watch(homepageServiceProvider);
  return service.getHomepageDetail(homepageId);
});

/// 홈페이지 부문 목록 프로바이더 (Family)
final homepageCategoriesProvider = FutureProvider.family<List<HomepageCategory>, int>((ref, homepageId) async {
  final service = ref.watch(homepageServiceProvider);
  return service.getCategories(homepageId);
});
