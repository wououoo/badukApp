/// 체크인 결과 모델
class CheckInResult {
  final bool success;
  final String? message;
  final String? checkInTime;
  final String? checkInDate;

  CheckInResult({
    required this.success,
    this.message,
    this.checkInTime,
    this.checkInDate,
  });

  factory CheckInResult.fromJson(Map<String, dynamic> json) {
    return CheckInResult(
      success: json['success'] ?? false,
      message: json['message'],
      checkInTime: json['checkInTime'],
      checkInDate: json['checkInDate'],
    );
  }

  factory CheckInResult.error(String message) {
    return CheckInResult(
      success: false,
      message: message,
    );
  }
}
