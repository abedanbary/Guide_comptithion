import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class MapViewScreen extends StatefulWidget {
  final String competitionId;
  final String roadId;
  final String competitionTitle;

  const MapViewScreen({
    super.key,
    required this.competitionId,
    required this.roadId,
    required this.competitionTitle,
  });

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _waypoints = [];
  LatLng? _currentLocation;
  int _currentWaypointIndex = 0;
  int _totalScore = 0;
  bool _isLoading = true;
  StreamSubscription<Position>? _positionStream;
  Set<int> _completedWaypoints = {};

  // Professional color palette
  static const Color primaryBlue = Color(0xFF3D5A80);
  static const Color accentGold = Color(0xFFE9C46A);
  static const Color lightBlue = Color(0xFF6B89A8);
  static const Color darkBlue = Color(0xFF2A3F5F);

  @override
  void initState() {
    super.initState();
    _loadRoadData();
    _startLocationTracking();
  }

  Future<void> _loadRoadData() async {
    try {
      final roadDoc = await FirebaseFirestore.instance
          .collection('roads')
          .doc(widget.roadId)
          .get();

      if (roadDoc.exists) {
        final data = roadDoc.data();
        final points = data?['points'] as List;

        setState(() {
          _waypoints = points.map((p) => Map<String, dynamic>.from(p)).toList();
          _routePoints = points
              .map((p) => LatLng(p['latitude'] as double, p['longitude'] as double))
              .toList();
          _isLoading = false;
        });

        if (_routePoints.isNotEmpty) {
          _mapController.move(_routePoints.first, 15);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading route: $e', isError: true);
    }
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Please enable location services', isError: true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied', isError: true);
        return;
      }
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      _checkProximityToWaypoint();
    });
  }

  void _checkProximityToWaypoint() {
    if (_currentLocation == null || _waypoints.isEmpty) return;

    for (int i = 0; i < _waypoints.length; i++) {
      if (_completedWaypoints.contains(i)) continue;

      final waypoint = _waypoints[i];
      final waypointLatLng = LatLng(
        waypoint['latitude'] as double,
        waypoint['longitude'] as double,
      );

      final distance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        waypointLatLng.latitude,
        waypointLatLng.longitude,
      );

      // If within 50 meters, show quiz
      if (distance <= 50) {
        _showQuizDialog(i);
        break;
      }
    }
  }

  void _showQuizDialog(int waypointIndex) {
    final waypoint = _waypoints[waypointIndex];
    final question = waypoint['question'] ?? 'No question available';
    final options = List<String>.from(waypoint['options'] ?? []);
    final correctIndex = waypoint['correctIndex'] ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.quiz, color: primaryBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                waypoint['name'] ?? 'Waypoint ${waypointIndex + 1}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ...options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleAnswer(waypointIndex, index, correctIndex);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: darkBlue,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(option)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _handleAnswer(int waypointIndex, int selectedIndex, int correctIndex) {
    setState(() {
      _completedWaypoints.add(waypointIndex);
    });

    if (selectedIndex == correctIndex) {
      setState(() => _totalScore += 10);
      _showSnackBar('Correct! +10 points', isError: false);
    } else {
      _showSnackBar('Incorrect answer', isError: true);
    }

    // Check if all waypoints completed
    if (_completedWaypoints.length == _waypoints.length) {
      _completeCompetition();
    }
  }

  Future<void> _completeCompetition() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.competitionId)
          .update({
        'scores.${currentUser.uid}': _totalScore,
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.emoji_events, color: accentGold, size: 40),
                SizedBox(width: 12),
                Text('Competition Complete!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Congratulations!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your Score: $_totalScore points',
                  style: const TextStyle(fontSize: 24, color: primaryBlue),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Error saving score: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.competitionTitle),
        backgroundColor: primaryBlue,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: accentGold,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: darkBlue, size: 20),
                const SizedBox(width: 6),
                Text(
                  '$_totalScore pts',
                  style: const TextStyle(
                    color: darkBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _routePoints.isNotEmpty
                        ? _routePoints.first
                        : LatLng(31.9539, 35.9106),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: primaryBlue,
                            strokeWidth: 5,
                            borderColor: Colors.white,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        ..._waypoints.asMap().entries.map((entry) {
                          final index = entry.key;
                          final waypoint = entry.value;
                          final isCompleted = _completedWaypoints.contains(index);
                          return Marker(
                            point: LatLng(
                              waypoint['latitude'] as double,
                              waypoint['longitude'] as double,
                            ),
                            width: 50,
                            height: 50,
                            child: _buildWaypointMarker(index, isCompleted),
                          );
                        }).toList(),
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: primaryBlue),
                            const SizedBox(width: 8),
                            Text(
                              'Progress: ${_completedWaypoints.length}/${_waypoints.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${((_completedWaypoints.length / _waypoints.length) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWaypointMarker(int index, bool isCompleted) {
    final Color markerColor = isCompleted
        ? Colors.green.shade600
        : index == 0
            ? primaryBlue
            : index == _waypoints.length - 1
                ? Colors.red.shade600
                : accentGold;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: markerColor.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}
