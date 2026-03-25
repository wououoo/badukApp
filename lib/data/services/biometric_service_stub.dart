/// 웹 빌드용 BiometricService stub
/// 웹에서는 생체 인증이 지원되지 않으므로 모든 메서드가 비활성 상태를 반환
class BiometricServiceStub {
  static final BiometricServiceStub _instance = BiometricServiceStub._();
  static BiometricServiceStub get instance => _instance;
  BiometricServiceStub._();

  Future<bool> isAvailable() async => false;
  Future<bool> isEnabled() async => false;
  Future<void> setEnabled(bool enabled) async {}
  Future<bool> authenticate() async => false;
}
