import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// One-shot user position used by "Locales cerca de vos". Returns null
/// when the service is off or the user denies permission — callers treat
/// that as "feature unavailable", never as an error.
class UserLocationService {
  const UserLocationService();

  static const Distance _distance = Distance();

  Future<LatLng?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Meters between [user] and [tenant], or null when the store has no
  /// coordinates yet.
  static double? distanceTo(TenantModel tenant, LatLng? user) {
    if (user == null || tenant.lat == null || tenant.lng == null) {
      return null;
    }
    return _distance.as(
      LengthUnit.Meter,
      user,
      LatLng(tenant.lat!, tenant.lng!),
    );
  }

  /// "350 m" / "1,2 km".
  static String distanceLabel(double meters) {
    if (meters < 950) return '${meters.round()} m';
    final double km = meters / 1000;
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}
