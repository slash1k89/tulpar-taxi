import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/route_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

void main() {
  const myrzhasheva66 = LatLng(51.95968734, 66.40240018);
  const myrzhasheva15 = LatLng(51.95797260, 66.41418792);
  const tynIgerushiler2 = LatLng(51.94877692, 66.40612280);
  const tynIgerushiler66 = LatLng(51.95121664, 66.39730188);
  const tynIgerushiler83a = LatLng(51.95232468, 66.39390438);

  setUp(() {
    RouteService.apiClient = TulparApiClient(
      tokenProvider: () async => 'route-test-token',
      client: MockClient((request) async {
        final ordered = <LatLng>[
          LatLng(
            double.parse(request.url.queryParameters['startLat']!),
            double.parse(request.url.queryParameters['startLng']!),
          ),
          ..._parseWaypoints(request.url.queryParameters['waypoints']),
          LatLng(
            double.parse(request.url.queryParameters['destLat']!),
            double.parse(request.url.queryParameters['destLng']!),
          ),
        ];
        return http.Response(
          jsonEncode({
            'geometry': ordered
                .map((point) => {'lat': point.latitude, 'lng': point.longitude})
                .toList(),
            'steps': const [],
            'distanceMeters': 1000,
            'durationSeconds': 120,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  final cases = <({String name, LatLng start, List<LatLng> via, LatLng end})>[
    (
      name: 'house to house',
      start: myrzhasheva66,
      via: const [],
      end: tynIgerushiler66,
    ),
    (
      name: 'opposite parts of Esil',
      start: myrzhasheva15,
      via: const [],
      end: tynIgerushiler83a,
    ),
    (
      name: 'street with exact house number',
      start: tynIgerushiler2,
      via: const [],
      end: myrzhasheva66,
    ),
    (
      name: 'pickup one stop destination',
      start: myrzhasheva15,
      via: const [myrzhasheva66],
      end: tynIgerushiler66,
    ),
    (
      name: 'pickup three stops destination',
      start: myrzhasheva15,
      via: const [myrzhasheva66, tynIgerushiler2, tynIgerushiler66],
      end: tynIgerushiler83a,
    ),
  ];

  for (final scenario in cases) {
    test('${scenario.name} preserves Esil coordinate order', () async {
      final route = await RouteService.fetchRoute(
        startLat: scenario.start.latitude,
        startLng: scenario.start.longitude,
        destLat: scenario.end.latitude,
        destLng: scenario.end.longitude,
        intermediatePoints: scenario.via,
      );
      final expected = [scenario.start, ...scenario.via, scenario.end];
      expect(route.geometry, expected);
      expect(route.geometry.first.latitude, inInclusiveRange(51, 52));
      expect(route.geometry.first.longitude, inInclusiveRange(66, 67));
      final diagnostics = RouteEndpointDiagnostics.fromRoute(
        geometry: route.geometry,
        expectedStart: scenario.start,
        expectedDestination: scenario.end,
      );
      expect(diagnostics.startWithinTolerance, isTrue);
      expect(diagnostics.destinationWithinTolerance, isTrue);
    });
  }

  test(
    'remaining route does not reintroduce an already reached stop',
    () async {
      final route = await RouteService.fetchRoute(
        startLat: myrzhasheva66.latitude,
        startLng: myrzhasheva66.longitude,
        destLat: tynIgerushiler83a.latitude,
        destLng: tynIgerushiler83a.longitude,
        intermediatePoints: const [tynIgerushiler66],
      );
      expect(route.geometry, const [
        myrzhasheva66,
        tynIgerushiler66,
        tynIgerushiler83a,
      ]);
      expect(route.geometry, isNot(contains(tynIgerushiler2)));
    },
  );
}

List<LatLng> _parseWaypoints(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  return raw.split(';').map((pair) {
    final values = pair.split(',').map(double.parse).toList();
    return LatLng(values[1], values[0]);
  }).toList();
}
