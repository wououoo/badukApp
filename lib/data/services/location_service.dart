import 'package:geolocator/geolocator.dart';
import '../api/api_client.dart';

class LocationService {
  static final LocationService _instance = LocationService._();
  static LocationService get instance => _instance;
  LocationService._();

  /// 현재 위치 가져오기 (권한 요청 포함)
  Future<Position?> getCurrentPosition() async {
    // 위치 서비스 활성화 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    // 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    // 현재 위치 반환
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// 두 좌표 사이 거리 (km)
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// 거리 포맷팅
  String formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()}m';
    }
    return '${km.toStringAsFixed(1)}km';
  }

  /// 근처 대회 조회 API
  Future<List<Map<String, dynamic>>> getNearbyContests({
    required double lat,
    required double lng,
    double radiusKm = 50,
  }) async {
    final response = await ApiClient().get(
      '/location/nearby-contests',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius': radiusKm,
      },
    );

    final data = response.data;
    if (data is Map && data['contests'] != null) {
      return List<Map<String, dynamic>>.from(data['contests']);
    }
    return [];
  }
}
