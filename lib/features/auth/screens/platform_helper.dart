import 'package:flutter/foundation.dart';

/// iOS 여부를 웹-안전하게 판단
bool get isIOS {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS;
}
