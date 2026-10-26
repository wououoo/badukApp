import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 수정/정정 공통 유틸 — 라운드 삭제·리셋 시 비밀번호 게이트 처리.
///
/// 서버 프로토콜(웹과 동일): password 없이 호출 → 응답이 {requirePassword:true}면
/// 4자리 비밀번호를 받아 재호출. {success:false}(비번 외 사유)면 메시지 표시.
/// 성공하면 true 반환 → 호출부가 화면 reload.
class HostCorrection {
  /// [action] 은 password(nullable)를 받아 서버 응답 Map 을 돌려주는 함수.
  /// 먼저 password=null 로 호출하고, requirePassword면 다이얼로그로 받아 재호출.
  static Future<bool> runDelete(
    BuildContext context, {
    required String title,
    required String confirmMessage,
    required Future<Map<String, dynamic>> Function(String? password) action,
  }) async {
    // 1) 삭제 확인
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(confirmMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return false;

    // 2) 비번 없이 1차 시도
    Map<String, dynamic> res;
    try {
      res = await action(null);
    } catch (_) {
      if (context.mounted) _toast(context, '처리 중 오류가 발생했습니다.');
      return false;
    }

    // 3) 비번 요구 시 최대 3회 재시도
    var attempts = 0;
    while (res['requirePassword'] == true && attempts < 3) {
      if (!context.mounted) return false;
      final pw = await _askPassword(context,
          retry: attempts > 0 ? (res['message']?.toString()) : null);
      if (pw == null) return false; // 사용자가 취소
      attempts++;
      try {
        res = await action(pw);
      } catch (_) {
        if (context.mounted) _toast(context, '처리 중 오류가 발생했습니다.');
        return false;
      }
    }

    // 4) 결과 판정
    if (res['success'] == true || res['status'] == 'SUCCESS') {
      if (context.mounted) _toast(context, '삭제되었습니다.');
      return true;
    }
    if (res['requirePassword'] == true) {
      if (context.mounted) _toast(context, '비밀번호 확인에 실패했습니다.');
      return false;
    }
    // 토너먼트 resetTournament 처럼 ResponseEntity<String> 성공(success 키 없음) 처리
    if (res.isEmpty || (!res.containsKey('success') && !res.containsKey('status'))) {
      if (context.mounted) _toast(context, '처리되었습니다.');
      return true;
    }
    if (context.mounted) {
      _toast(context, res['message']?.toString() ?? '삭제에 실패했습니다.');
    }
    return false;
  }

  static Future<String?> _askPassword(BuildContext context, {String? retry}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 비밀번호'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (retry != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(retry,
                  style: TextStyle(fontSize: 12.5, color: AppColors.error)),
            ),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            autofocus: true,
            maxLength: 4,
            decoration: const InputDecoration(
              hintText: '4자리 비밀번호',
              counterText: '',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('확인')),
        ],
      ),
    );
  }

  static void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
}
