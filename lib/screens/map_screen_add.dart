import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/road.dart';
import '../models/point.dart';
import '../models/quiz.dart';
import '../models/route_result.dart';
import '../servers/osrm_route_service.dart';
import '../widgets/road_name_input.dart';
import '../widgets/save_road_button.dart';
import '../widgets/point_dialog.dart';
import 'my_roads_screen.dart';

class MapCreateScreen extends StatefulWidget {
  const MapCreateScreen({super.key});

  @override
  State<MapCreateScreen> createState() => _MapCreateScreenState();
}

class _MapCreateScreenState extends State<MapCreateScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _roadNameController = TextEditingController();
  List<LatLng> _points = [];
  List<Map<String, dynamic>> _pointDetails = []; // تفاصيل كل نقطة
  RouteResult? _currentRoute;
  bool _isLoadingRoute = false;

  /// 📌 عند الضغط على الخريطة
  Future<void> _onMapTap(LatLng latLng) async {
    // فتح نافذة PointDialog
    final result = await showDialog(
      context: context,
      builder: (context) => const PointDialog(),
    );

    // إذا المستخدم ضغط "Add" وأدخل بيانات صحيحة
    if (result != null) {
      setState(() {
        _points.add(latLng);
        _pointDetails.add({
          'latitude': latLng.latitude,
          'longitude': latLng.longitude,
          'name': result['name'],
          'question': result['question'],
          'options': result['options'],
          'correctIndex': result['correctIndex'],
        });
      });

      // ارسم الطريق بين النقاط
      if (_points.length >= 2) {
        await _getRouteBetweenPoints();
      }
    }
  }

  /// 🛣️ رسم الطريق بين نقطتين باستخدام OpenRouteService
  Future<void> _getRouteBetweenPoints() async {
    setState(() => _isLoadingRoute = true);
    final start = _points[_points.length - 2];
    final end = _points.last;

    final route = await ORSRouteService.getRoute(start, end);
    if (route != null) {
      setState(() {
        if (_currentRoute == null) {
          _currentRoute = route;
        } else {
          _currentRoute!.points.addAll(route.points);
        }
      });
    }
    setState(() => _isLoadingRoute = false);
  }

  /// 💾 حفظ الطريق في Firebase Firestore
  Future<void> _saveRoad() async {
    if (_roadNameController.text.isEmpty || _points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم الطريق وإضافة نقاط')),
      );
      return;
    }

    final road = {
      'roadName': _roadNameController.text,
      'createdAt': DateTime.now(),
      'points': _pointDetails,
    };

    try {
      await FirebaseFirestore.instance.collection('roads').add(road);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ الطريق بنجاح في Firebase Firestore!'),
        ),
      );

      setState(() {
        _points.clear();
        _pointDetails.clear();
        _currentRoute = null;
        _roadNameController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ فشل حفظ الطريق: $e')));
    }
  }

  /// 🧹 مسح كل شيء
  void _clearAll() {
    setState(() {
      _points.clear();
      _pointDetails.clear();
      _currentRoute = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hiking Route 🥾'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyRoadsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          RoadNameInput(controller: _roadNameController),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(31.9539, 35.9106),
                    initialZoom: 13,
                    onTap: (tapPosition, latLng) => _onMapTap(latLng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    if (_currentRoute != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _currentRoute!.points,
                            color: Colors.green,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: _points
                          .map(
                            (p) => Marker(
                              point: p,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 30,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                if (_isLoadingRoute)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  ),
              ],
            ),
          ),
          SaveRoadButton(onPressed: _saveRoad),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
