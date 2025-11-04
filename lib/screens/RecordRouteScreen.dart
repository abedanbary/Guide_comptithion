import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import '../config/cloudinary_config.dart';
import '../utils/route_helpers.dart';

class RecordRouteScreen extends StatefulWidget {
  const RecordRouteScreen({super.key});

  @override
  State<RecordRouteScreen> createState() => _RecordRouteScreenState();
}

class _RecordRouteScreenState extends State<RecordRouteScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _roadNameController = TextEditingController();

  // Recording state
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isFinished = false;
  List<LatLng> _recordedPoints = [];
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;

  // Stats
  double _totalDistance = 0.0;
  int _totalTime = 0; // in seconds
  DateTime? _startTime;
  Timer? _timer;

  // Waypoints after recording
  List<Map<String, dynamic>> _waypoints = [];
  XFile? _selectedImage;
  bool _isUploadingImage = false;

  // Colors
  static const Color primaryBlue = Color(0xFF3D5A80);
  static const Color accentGold = Color(0xFFE9C46A);
  static const Color lightBlue = Color(0xFF6B89A8);
  static const Color darkBlue = Color(0xFF2A3F5F);
  static const Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    _roadNameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
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

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16);
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _startTime = DateTime.now();
      _recordedPoints.clear();
      _totalDistance = 0.0;
      _totalTime = 0;
    });

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording && !_isPaused) {
        setState(() => _totalTime++);
      }
    });

    // Start GPS tracking
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Record every 3 meters
      ),
    ).listen((Position position) {
      if (_isRecording && !_isPaused) {
        final newPoint = LatLng(position.latitude, position.longitude);

        setState(() {
          if (_recordedPoints.isNotEmpty) {
            // Calculate distance from last point
            final lastPoint = _recordedPoints.last;
            final distance = Geolocator.distanceBetween(
              lastPoint.latitude,
              lastPoint.longitude,
              newPoint.latitude,
              newPoint.longitude,
            );
            _totalDistance += distance;
          }

          _recordedPoints.add(newPoint);
          _currentLocation = newPoint;

          // Center map on current location
          _mapController.move(newPoint, _mapController.camera.zoom);
        });
      }
    });

    _showSnackBar('Recording started! Start walking...', isError: false);
  }

  void _pauseRecording() {
    setState(() => _isPaused = !_isPaused);
    _showSnackBar(_isPaused ? 'Recording paused' : 'Recording resumed',
        isError: false);
  }

  void _stopRecording() {
    if (_recordedPoints.length < 2) {
      _showSnackBar('Record at least a short route before stopping',
          isError: true);
      return;
    }

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _isFinished = true;
    });

    _positionStream?.cancel();
    _timer?.cancel();

    _showSnackBar('Recording stopped! Add waypoints and details',
        isError: false);
  }

  Future<void> _saveRoute() async {
    if (_roadNameController.text.isEmpty) {
      _showSnackBar('Please enter a route name', isError: true);
      return;
    }

    if (_waypoints.isEmpty) {
      _showSnackBar('Please add at least one waypoint with quiz', isError: true);
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      final roadId = DateTime.now().millisecondsSinceEpoch;

      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        if (!CloudinaryConfig.isConfigured) {
          throw Exception(CloudinaryConfig.configurationError);
        }

        final cloudinary = CloudinaryPublic(
          CloudinaryConfig.cloudName,
          CloudinaryConfig.routeUploadPreset,
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

      // Save route polyline
      final List<Map<String, dynamic>> routePolyline = [];
      for (var point in _recordedPoints) {
        routePolyline.add({
          'latitude': point.latitude,
          'longitude': point.longitude,
        });
      }

      // Number waypoints
      final List<Map<String, dynamic>> numberedWaypoints = [];
      for (int i = 0; i < _waypoints.length; i++) {
        numberedWaypoints.add({'id': i + 1, ..._waypoints[i]});
      }

      final road = {
        'id': roadId,
        'roadName': _roadNameController.text,
        'createdAt': DateTime.now(),
        'points': numberedWaypoints,
        'routePolyline': routePolyline,
        'recordedDistance': _totalDistance,
        'recordedTime': _totalTime,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      await FirebaseFirestore.instance.collection('roads').add(road);

      if (mounted) {
        _showSnackBar('Route saved successfully!', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error saving route: $e', isError: true);
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  void _addWaypoint() {
    if (_recordedPoints.isEmpty) {
      _showSnackBar('No route recorded yet', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _WaypointDialog(
        recordedPoints: _recordedPoints,
        onAdd: (waypoint) {
          setState(() => _waypoints.add(waypoint));
          _showSnackBar('Waypoint added!', isError: false);
        },
      ),
    );
  }

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
        _showSnackBar('Image selected successfully!', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error selecting image', isError: true);
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
        title: Text(_isFinished ? 'Add Route Details' : 'Record Route'),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: _isFinished ? _buildDetailsView() : _buildRecordingView(),
    );
  }

  Widget _buildRecordingView() {
    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation ?? LatLng(31.9539, 35.9106),
            initialZoom: 16,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            if (_recordedPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _recordedPoints,
                    color: primaryBlue,
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (_currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation!,
                    width: 50,
                    height: 50,
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
                        Icons.navigation,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),

        // Stats Card
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      Icons.straighten,
                      RouteHelpers.formatDistance(_totalDistance / 1000),
                      'Distance',
                    ),
                    _buildStat(
                      Icons.access_time,
                      RouteHelpers.formatTime(_totalTime ~/ 60),
                      'Time',
                    ),
                    _buildStat(
                      Icons.my_location,
                      '${_recordedPoints.length}',
                      'Points',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Control Buttons
        Positioned(
          bottom: 30,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_isRecording)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (_isRecording) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pauseRecording,
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      label: Text(_isPaused ? 'Resume' : 'Pause'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop),
                      label: const Text('Finish'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Route Name',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _roadNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter route name...',
                    prefixIcon: const Icon(Icons.hiking_rounded, color: primaryBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Route Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recorded Route Stats',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        Icons.straighten,
                        RouteHelpers.formatDistance(_totalDistance / 1000),
                        'Distance',
                        Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        Icons.access_time,
                        RouteHelpers.formatTime(_totalTime ~/ 60),
                        'Duration',
                        Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Route Image
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Route Image (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                          style: BorderStyle.solid,
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

          const SizedBox(height: 16),

          // Waypoints
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Waypoints & Quizzes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addWaypoint,
                      icon: const Icon(Icons.add_location_alt, size: 18),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_waypoints.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'No waypoints added yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                if (_waypoints.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _waypoints.length,
                    itemBuilder: (context, index) {
                      final waypoint = _waypoints[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryBlue,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(waypoint['name'] ?? 'Waypoint ${index + 1}'),
                          subtitle: Text(
                            waypoint['question'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red.shade700,
                            onPressed: () {
                              setState(() => _waypoints.removeAt(index));
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isUploadingImage ? null : _saveRoute,
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
                        Icon(Icons.check, color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: primaryBlue, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// Waypoint Dialog
class _WaypointDialog extends StatefulWidget {
  final List<LatLng> recordedPoints;
  final Function(Map<String, dynamic>) onAdd;

  const _WaypointDialog({
    required this.recordedPoints,
    required this.onAdd,
  });

  @override
  State<_WaypointDialog> createState() => _WaypointDialogState();
}

class _WaypointDialogState extends State<_WaypointDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctIndex = 0;
  int _selectedPointIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Waypoint'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Point selector
            const Text(
              'Select point on route:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedPointIndex,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: List.generate(
                (widget.recordedPoints.length / 10).ceil(),
                (index) {
                  final pointIndex = index * 10;
                  if (pointIndex < widget.recordedPoints.length) {
                    final point = widget.recordedPoints[pointIndex];
                    return DropdownMenuItem(
                      value: pointIndex,
                      child: Text(
                        'Point ${pointIndex + 1}: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                      ),
                    );
                  }
                  return null;
                },
              ).whereType<DropdownMenuItem<int>>().toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPointIndex = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Waypoint Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Quiz Question',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            const Text(
              'Options:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Radio<int>(
                      value: index,
                      groupValue: _correctIndex,
                      onChanged: (value) {
                        setState(() => _correctIndex = value!);
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Option ${index + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty ||
                _questionController.text.isEmpty) {
              return;
            }

            final point = widget.recordedPoints[_selectedPointIndex];
            final options = _optionControllers.map((c) => c.text).toList();

            if (options.any((o) => o.isEmpty)) {
              return;
            }

            widget.onAdd({
              'name': _nameController.text,
              'latitude': point.latitude,
              'longitude': point.longitude,
              'question': _questionController.text,
              'options': options,
              'correctIndex': _correctIndex,
            });

            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
