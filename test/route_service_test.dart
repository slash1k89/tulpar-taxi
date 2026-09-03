import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/screens/driver/driver_map_screen.dart';
import 'package:taxi_esil/services/route_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

Map<String, dynamic> _routeJson({Object? steps}) => {
  'geometry': [
    {'lat': 51.9555, 'lng': 66.4042},
    {'lat': 51.96, 'lng': 66.41},
  ],
  'steps':
      steps ??
      [
        {
          'name': 'Абая',
          'distanceMeters': 345.6,
          'durationSeconds': 42.5,
          'maneuver': {
            'type': 'roundabout',
            'modifier': 'right',
            'location': [66.41, 51.96],
            'exit': 2,
          },
        },
      ],
  'distanceMeters': 1234,
  'durationSeconds': 180,
};

void main() {
  test(
    'RouteService uses authenticated Tulpar routing API and parses geometry',
    () async {
      var calls = 0;
      late Uri requestedUri;
      late String? authorization;
      final client = MockClient((request) async {
        calls++;
        requestedUri = request.url;
        authorization = request.headers['Authorization'];
        return http.Response(
          jsonEncode(_routeJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      RouteService.apiClient = TulparApiClient(
        client: client,
        tokenProvider: () async => 'test-token',
      );

      final geometry = await RouteService.fetchRouteGeometry(
        startLat: 51.9555,
        startLng: 66.4042,
        destLat: 51.96,
        destLng: 66.41,
      );
      final steps = await RouteService.fetchSteps(
        startLat: 51.9555,
        startLng: 66.4042,
        destLat: 51.96,
        destLng: 66.41,
      );

      expect(requestedUri.path, '/api/routing/route');
      expect(requestedUri.host, 'api.tulpartaxi.kz');
      expect(authorization, 'Bearer test-token');
      expect(geometry, const [LatLng(51.9555, 66.4042), LatLng(51.96, 66.41)]);
      expect(steps.single.modifier, 'right');
      expect(steps.single.distanceMeters, 345.6);
      expect(steps.single.durationSeconds, 42.5);
      expect(steps.single.exitNumber, 2);
      expect(
        calls,
        1,
        reason: 'geometry and steps must share one route request',
      );
    },
  );

  test('malformed steps do not discard valid geometry', () {
    final result = RouteService.parseRouteResponse(
      _routeJson(
        steps: [
          {
            'maneuver': {
              'location': ['bad', null],
            },
          },
        ],
      ),
    );
    expect(result.geometry, hasLength(2));
    expect(result.steps, isEmpty);
  });

  test('old route response safely defaults new optional step fields', () {
    final result = RouteService.parseRouteResponse(
      _routeJson(
        steps: [
          {
            'name': 'Абая',
            'maneuver': {
              'type': 'turn',
              'modifier': 'left',
              'location': [66.41, 51.96],
            },
          },
        ],
      ),
    );

    expect(result.steps.single.distanceMeters, 0);
    expect(result.steps.single.durationSeconds, 0);
    expect(result.steps.single.exitNumber, isNull);
  });

  test('accepted routes to pickup and in_progress routes to destination', () {
    final order = <String, dynamic>{
      'status': 'accepted',
      'fromLat': 51.95,
      'fromLng': 66.40,
      'toLat': 51.97,
      'toLng': 66.42,
    };
    expect(driverRouteDestination(order), const LatLng(51.95, 66.40));
    expect(
      driverRouteDestination(order, statusOverride: 'in_progress'),
      const LatLng(51.97, 66.42),
    );
  });

  test('active RouteService has no direct public OSRM reference', () {
    final source = File('lib/services/route_service.dart').readAsStringSync();
    expect(source, isNot(contains('router.project-osrm.org')));
  });
}
