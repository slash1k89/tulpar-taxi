import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'geocoding_service.dart';
import 'tulpar_api_client.dart';

typedef ReverseGeocode = Future<String> Function(double lat, double lng);

class ResolvedMapPoint {
  const ResolvedMapPoint({required this.point, required this.address});

  final LatLng point;
  final String address;
}

class MapPointAddressResolver {
  MapPointAddressResolver({ReverseGeocode? reverseGeocode})
    : _reverseGeocode = reverseGeocode ?? GeocodingService.reverseGeocode;

  final ReverseGeocode _reverseGeocode;

  Future<ResolvedMapPoint> resolve(LatLng point) async {
    try {
      final address = (await _reverseGeocode(
        point.latitude,
        point.longitude,
      )).trim();
      if (address.isNotEmpty) {
        return ResolvedMapPoint(point: point, address: address);
      }
    } catch (error) {
      if (error is TulparApiException) {
        debugPrint(
          '[ReverseGeocoding] status=${error.statusCode} '
          'message=${error.message}',
        );
      } else {
        debugPrint('[ReverseGeocoding] error=$error');
      }
    }

    return ResolvedMapPoint(
      point: point,
      address:
          'Точка на карте '
          '(${point.latitude.toStringAsFixed(3)}, '
          '${point.longitude.toStringAsFixed(3)})',
    );
  }
}
