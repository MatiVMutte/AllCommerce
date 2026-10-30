import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One address suggestion returned by OpenStreetMap Nominatim.
class AddressSuggestion {
  const AddressSuggestion({
    required this.displayName,
    required this.shortLabel,
    required this.point,
  });

  final String displayName;
  final String shortLabel;
  final LatLng point;

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    final String display = (json['display_name'] as String? ?? '').trim();
    final Map<String, dynamic>? addr = json['address'] as Map<String, dynamic>?;
    final String shortLabel = _buildShortLabel(addr, display);
    return AddressSuggestion(
      displayName: display,
      shortLabel: shortLabel,
      point: LatLng(
        double.parse(json['lat'].toString()),
        double.parse(json['lon'].toString()),
      ),
    );
  }

  static String _buildShortLabel(Map<String, dynamic>? addr, String fallback) {
    if (addr == null) return fallback;
    final String? road = (addr['road'] ?? addr['pedestrian']) as String?;
    final String? number = addr['house_number'] as String?;
    final String? area =
        (addr['suburb'] ??
                addr['neighbourhood'] ??
                addr['city'] ??
                addr['town'] ??
                addr['village'] ??
                addr['municipality'])
            as String?;
    final String? state = addr['state'] as String?;
    final String street = <String>[
      if (road != null && road.isNotEmpty) road,
      if (number != null && number.isNotEmpty) number,
    ].join(' ');
    final List<String> parts = <String>[
      if (street.isNotEmpty) street,
      if (area != null && area.isNotEmpty) area,
      if (state != null && state.isNotEmpty && state != area) state,
    ];
    if (parts.isEmpty) return fallback;
    return parts.join(', ');
  }
}

/// Lightweight Nominatim (OpenStreetMap) forward geocoder.
class NominatimGeocoder {
  const NominatimGeocoder({this.client});

  final http.Client? client;

  Future<List<AddressSuggestion>> search(String rawQuery) async {
    final String query = rawQuery.trim();
    if (query.length < 3) return const <AddressSuggestion>[];
    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '5',
        'countrycodes': 'ar',
      },
    );
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response res = await httpClient
          .get(
            uri,
            headers: const <String, String>{
              'User-Agent': 'AllCommerce/1.0 (app.allcommerce)',
              'Accept-Language': 'es-AR,es;q=0.9',
            },
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const <AddressSuggestion>[];
      final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(AddressSuggestion.fromJson)
          .toList();
    } catch (_) {
      return const <AddressSuggestion>[];
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
