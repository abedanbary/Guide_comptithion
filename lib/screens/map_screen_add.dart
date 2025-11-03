import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';

import '../models/road.dart';
import '../models/point.dart';
import '../models/quiz.dart';
import '../models/route_result.dart';
import '../servers/osrm_route_service.dart';
import '../widgets/road_name_input.dart';
import '../widgets/save_road_button.dart';
import '../widgets/point_dialog.dart';
import 'competition_screen.dart';

class MapCreateScreen extends StatefulWidget {
  const MapCreateScreen({super.key});

  @override
  State<MapCreateScreen> createState() => _MapCreateScreenState();
}

class _MapCreateScreenState extends State<MapCreateScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _roadNameController = TextEditingController();
  List<LatLng> _points = [];
  List<Map<String, dynamic>> _pointDetails = [];
  RouteResult? _currentRoute;
  bool _isLoadingRoute = false;
  XFile? _selectedImage;
  bool _isUploadingImage = false;

  // Professional color palette matching login/register
  static const Color primaryBlue = Color(0xFF3D5A80);
  static const Color accentGold = Color(0xFFE9C46A);
  static const Color lightBlue = Color(0xFF6B89A8);
  static const Color darkBlue = Color(0xFF2A3F5F);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color cardColor = Colors.white;


  /// Handle map tap: open dialog to add point details
  Future<void> _onMapTap(LatLng latLng) async {
    final result = await showDialog(
      context: context,
      builder: (context) => const PointDialog(),
    );

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

      if (_points.length >= 2) {
        await _getRouteBetweenPoints();
      }
    }
  }

  /// Get route between two points
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

  /// Pick image for route
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        setState(() => _selectedImage = image);
        _showSnackBar('Image selected successfully!');
      }
    } catch (e) {
      _showSnackBar('Error selecting image', isError: true);
    }
  }

  /// Save road to Firebase Firestore
  Future<void> _saveRoad() async {
    if (_roadNameController.text.isEmpty || _points.isEmpty) {
      _showSnackBar(
        'Please enter a route name and add waypoints',
        isError: true,
      );
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      final roadId = DateTime.now().millisecondsSinceEpoch;

      final List<Map<String, dynamic>> numberedPoints = [];
      for (int i = 0; i < _pointDetails.length; i++) {
        final point = _pointDetails[i];
        numberedPoints.add({'id': i + 1, ...point});
      }

      // Save route polyline points for display
      final List<Map<String, dynamic>> routePolyline = [];
      if (_currentRoute != null) {
        for (var point in _currentRoute!.points) {
          routePolyline.add({
            'latitude': point.latitude,
            'longitude': point.longitude,
          });
        }
      }

      // Upload image if selected using Cloudinary
      String? imageUrl;
      if (_selectedImage != null) {
        // TODO: Replace with your Cloudinary credentials
        // Get them from: https://console.cloudinary.com/
        final cloudinary = CloudinaryPublic(
          'YOUR_CLOUD_NAME',  // مثل: 'dxxxxxxx'
          'YOUR_UPLOAD_PRESET', // اختر اسم مثل: 'route_photos'
          cache: false,
        );

        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            _selectedImage!.path,
            folder: 'route_images',
            resourceType: CloudinaryResourceType.Image,
          ),
        );

        imageUrl = response.secureUrl;
      }

      final road = {
        'id': roadId,
        'roadName': _roadNameController.text,
        'createdAt': DateTime.now(),
        'points': numberedPoints,
        'routePolyline': routePolyline, // Save complete route path
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      await FirebaseFirestore.instance.collection('roads').add(road);
      _showSnackBar('Route saved successfully!');

      setState(() {
        _points.clear();
        _pointDetails.clear();
        _currentRoute = null;
        _roadNameController.clear();
        _selectedImage = null;
      });
    } catch (e) {
      _showSnackBar('Failed to save route. Please try again.', isError: true);
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  /// Clear all current data from map
  void _clearAll() {
    if (_points.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Clear Map?'),
          ],
        ),
        content: const Text(
          'This will remove all waypoints and routes from the map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _points.clear();
                _pointDetails.clear();
                _currentRoute = null;
                _selectedImage = null;
              });
              Navigator.pop(context);
              _showSnackBar('Map cleared');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Show professional snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar - matching login/register style
          SliverAppBar(
            expandedHeight: 0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: primaryBlue,
            title: const Row(
              children: [
                Icon(Icons.terrain, size: 24),
                SizedBox(width: 8),
                Text(
                  'Hiking Route Creator',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 22),
                tooltip: 'Clear Map',
                onPressed: _clearAll,
                color: Colors.white,
              ),
              IconButton(
                icon: const Icon(Icons.emoji_events_rounded, size: 22),
                tooltip: 'Create Competition',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CompetitionScreen()),
                  );
                },
                color: accentGold,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Route Name Input Card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Route Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: TextField(
                            controller: _roadNameController,
                            decoration: InputDecoration(
                              hintText: 'Enter route name...',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              prefixIcon: const Icon(
                                Icons.hiking_rounded,
                                color: primaryBlue,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Route Image Upload Card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Route Image (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_selectedImage != null)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_selectedImage!.path),
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedImage = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_selectedImage == null)
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: primaryBlue,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add Route Image',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Map Container
                Container(
                  height: MediaQuery.of(context).size.height * 0.55,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
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
                                  color: primaryBlue,
                                  strokeWidth: 6,
                                  borderColor: Colors.white,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: _points.asMap().entries.map((entry) {
                              final index = entry.key;
                              final point = entry.value;
                              return Marker(
                                point: point,
                                width: 50,
                                height: 50,
                                child: _buildMarker(index),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      // Loading overlay
                      if (_isLoadingRoute)
                        Container(
                          color: Colors.black.withOpacity(0.4),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: primaryBlue,
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Calculating route...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: darkBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Points counter badge
                      if (_points.isNotEmpty)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_points.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Save Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  child: _buildSaveButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(int index) {
    final isStart = index == 0;
    final isEnd = index == _points.length - 1;
    final Color markerColor = isStart
        ? primaryBlue
        : isEnd
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
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: markerColor, shape: BoxShape.circle),
          child: Center(
            child: Text(
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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isUploadingImage ? null : _saveRoad,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: primaryBlue.withOpacity(0.6),
        ),
        child: _isUploadingImage
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Saving...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Save Route',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _roadNameController.dispose();
    super.dispose();
  }
}
