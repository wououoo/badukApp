import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/support_service.dart';

/// SupportService 프로바이더
final supportServiceProvider = Provider<SupportService>((ref) => SupportService());

/// 공지사항 목록 프로바이더
final noticesProvider = FutureProvider<List<Notice>>((ref) async {
  final service = ref.watch(supportServiceProvider);
  return service.getNotices();
});

/// 중요 공지사항 프로바이더
final importantNoticesProvider = FutureProvider<List<Notice>>((ref) async {
  final service = ref.watch(supportServiceProvider);
  return service.getImportantNotices();
});

/// 공지사항 상세 프로바이더
final noticeDetailProvider = FutureProvider.family<Notice, int>((ref, id) async {
  final service = ref.watch(supportServiceProvider);
  return service.getNotice(id);
});

/// 내 문의 목록 프로바이더
final myInquiriesProvider = FutureProvider<List<Inquiry>>((ref) async {
  final service = ref.watch(supportServiceProvider);
  return service.getMyInquiries();
});

/// 문의 상세 프로바이더
final inquiryDetailProvider = FutureProvider.family<Inquiry, int>((ref, id) async {
  final service = ref.watch(supportServiceProvider);
  return service.getInquiry(id);
});
