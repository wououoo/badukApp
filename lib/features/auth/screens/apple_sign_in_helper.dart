import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 모바일용 Apple Sign In 헬퍼
Future<Map<String, String>?> performAppleSignIn() async {
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
  );

  final identityToken = credential.identityToken;
  if (identityToken == null) return null;

  return {
    'identityToken': identityToken,
    'userIdentifier': credential.userIdentifier ?? '',
    'authorizationCode': credential.authorizationCode ?? '',
  };
}
