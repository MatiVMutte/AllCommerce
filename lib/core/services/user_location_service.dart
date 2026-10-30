import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Outcome of a locate attempt so the UI can explain what to do next.
final class UserLocationResult {
  const UserLocationResult({
    this.position,
    this.permissionBlockedForever = false,
  });

  final LatLng? position;

  /// True when the browser/OS has the site permission hard-blocked —
  /// the only fix is the user re-enabling it from the address-bar icon.
  final bool permissionBlockedForever;
}

/// One-shot user position used by "Locales cerca de vos".
///
/// Every platform call is wrapped in a timeout: on web/desktop a hung
/// geolocation request (prompt ignored, no sensor) would otherwise keep
/// the UI spinner alive forever.
class UserLocationService {
  const UserLocationService();

  static const Distance _distance = Distance();

  Future<UserLocationResult> locate() async {
    try {
      final bool enabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
      if (!enabled) return const UserLocationResult();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 30),
          onTimeout: () => LocationPermission.denied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const UserLocationResult(permissionBlockedForever: true);
      }
      if (permission == LocationPermission.denied) {
        return const UserLocationResult();
      }

      // Fast path: a recent cached fix avoids the slow sensor lookup.
      // Not all platforms implement it (web throws) — failure just
      // falls through to the live lookup below.
      try {
        final Position? last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) <
                const Duration(minutes: 5)) {
          return UserLocationResult(
            position: LatLng(last.latitude, last.longitude),
          );
        }
      } catch (_) {}

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(const Duration(seconds: 12));
      return UserLocationResult(position: LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      return const UserLocationResult();
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
