import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_result.dart';

class ORSRouteService {
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/foot-hiking';
  static const String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjViMWFiMTE3NWM2NDRjNTRiMmU1MWNlMzM4ZWIyMTNkIiwiaCI6Im11cm11cjY0In0=';

  static Future<RouteResult?> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      '$_baseUrl?api_key=$_apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final geometry = data['features'][0]['geometry']['coordinates'];
      final distance =
          data['features'][0]['properties']['segments'][0]['distance'];
      final duration =
          data['features'][0]['properties']['segments'][0]['duration'];

      final points = geometry
          .map<LatLng>(
            (coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()),
          )
          .toList();

      return RouteResult(
        points: points,
        distanceMeters: distance.toDouble(),
        durationSeconds: duration.toDouble(),
      );
    } else {
      print('❌ Failed to get route: ${response.statusCode}');
      print(response.body);
      return null;
    }
  }
}
