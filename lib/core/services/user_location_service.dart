import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// One-shot user position used by "Locales cerca de vos". Returns null
/// when the service is off or the user denies permission — callers treat
/// that as "feature unavailable", never as an error.
///
/// Every platform call is wrapped in a timeout: on web/desktop a hung
/// geolocation request (prompt ignored, no sensor) would otherwise keep
/// the UI spinner alive forever.
class UserLocationService {
  const UserLocationService();

  static const Distance _distance = Distance();

  Future<LatLng?> currentPosition() async {
    try {
      final bool enabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
      if (!enabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 30),
          onTimeout: () => LocationPermission.denied,
        );
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Fast path: a recent cached fix avoids the slow sensor lookup.
      // Not all platforms implement it (web throws) — failure just
      // falls through to the live lookup below.
      try {
        final Position? last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) <
                const Duration(minutes: 5)) {
          return LatLng(last.latitude, last.longitude);
        }
      } catch (_) {}

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(const Duration(seconds: 12));
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
