import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import '../controllers/route_recording_controller.dart';
import '../models/waypoint.dart';
import '../utils/route_helpers.dart';
import '../widgets/waypoint_dialog.dart';

/// Screen for recording routes by walking with GPS tracking
class RecordRouteScreen extends StatefulWidget {
  const RecordRouteScreen({super.key});

  @override
  State<RecordRouteScreen> createState() => _RecordRouteScreenState();
}

class _RecordRouteScreenState extends State<RecordRouteScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _roadNameController = TextEditingController();
  final RouteRecordingController _controller = RouteRecordingController();

  // Professional color palette
  static const Color primaryBlue = Color(0xFF3D5A80);
  static const Color accentGold = Color(0xFFE9C46A);
  static const Color lightBlue = Color(0xFF6B89A8);
  static const Color darkBlue = Color(0xFF2A3F5F);
  static const Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    // Don't dispose controller - it's a singleton that persists
    _roadNameController.dispose();
    super.dispose();
  }

  /// Initialize location on startup
  Future<void> _initializeLocation() async {
    final success = await _controller.initializeLocation();
    if (success && _controller.currentLocation != null) {
      _mapController.move(_controller.currentLocation!, 16);
    } else if (_controller.errorMessage != null) {
      _showSnackBar(_controller.errorMessage!, isError: true);
    }
  }

  /// Listen to controller updates and update map
  void _onControllerUpdate() {
    if (_controller.currentLocation != null && _controller.isRecording) {
      _mapController.move(
        _controller.currentLocation!,
        _mapController.camera.zoom,
      );
    }
  }

  /// Start recording handler
  void _handleStartRecording() {
    _controller.startRecording();
    _showSnackBar('Recording started! Start walking...', isError: false);
  }

  /// Pause/Resume handler
  void _handlePauseResume() {
    _controller.togglePause();
    _showSnackBar(
      _controller.isPaused ? 'Recording paused' : 'Recording resumed',
      isError: false,
    );
  }

  /// Stop recording handler
  Future<void> _handleStopRecording() async {
    final success = await _controller.stopRecording();
    if (success) {
      _showSnackBar('Recording stopped! Add waypoints and details',
          isError: false);
    } else if (_controller.errorMessage != null) {
      _showSnackBar(_controller.errorMessage!, isError: true);
    }
  }

  /// Add waypoint during recording (at current location)
  void _handleAddWaypointDuringRecording() {
    if (!_controller.canAddWaypoint) {
      _showSnackBar('Waiting for GPS location...', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _QuickWaypointDialog(
        currentLocation: _controller.currentLocation!,
        onAdd: (waypoint) {
          _controller.addWaypointAtCurrentLocation(waypoint);
          _showSnackBar('Waypoint added at current location!', isError: false);
        },
      ),
    );
  }

  /// Add waypoint handler (after recording, select from points)
  void _handleAddWaypoint() {
    if (_controller.recordedPoints.isEmpty) {
      _showSnackBar('No route recorded yet', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => WaypointDialog(
        recordedPoints: _controller.recordedPoints,
        onAdd: (waypoint) {
          _controller.addWaypoint(waypoint);
          _showSnackBar('Waypoint added!', isError: false);
        },
      ),
    );
  }

  /// Pick image handler
  Future<void> _handlePickImage() async {
    final success = await _controller.pickImage();
    if (success) {
      _showSnackBar('Image selected successfully!', isError: false);
    } else if (_controller.errorMessage != null) {
      _showSnackBar(_controller.errorMessage!, isError: true);
    }
  }

  /// Save route handler
  Future<void> _handleSaveRoute() async {
    final success = await _controller.saveRoute(_roadNameController.text);
    if (success) {
      _showSnackBar('Route saved successfully!', isError: false);
      if (mounted) {
        Navigator.pop(context);
      }
    } else if (_controller.errorMessage != null) {
      _showSnackBar(_controller.errorMessage!, isError: true);
    }
  }

  /// Show snackbar message
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
        title: Text(_controller.isFinished ? 'Add Route Details' : 'Record Route'),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          return _controller.isFinished
              ? _buildDetailsView()
              : _buildRecordingView();
        },
      ),
      floatingActionButton: _controller.isRecording && !_controller.isFinished
          ? FloatingActionButton.extended(
              onPressed: _handleAddWaypointDuringRecording,
              backgroundColor: accentGold,
              icon: const Icon(Icons.add_location_alt, color: darkBlue),
              label: const Text(
                'Add Waypoint',
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  /// Build recording view with map
  Widget _buildRecordingView() {
    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _controller.currentLocation ?? LatLng(31.9539, 35.9106),
            initialZoom: 16,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            if (_controller.recordedPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _controller.recordedPoints,
                    color: primaryBlue,
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (_controller.currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _controller.currentLocation!,
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Accuracy circle
                        if (_controller.currentAccuracy > 0)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _controller.currentAccuracy < 10
                                  ? Colors.green.withOpacity(0.2)
                                  : _controller.currentAccuracy < 20
                                      ? Colors.orange.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                              border: Border.all(
                                color: _controller.currentAccuracy < 10
                                    ? Colors.green
                                    : _controller.currentAccuracy < 20
                                        ? Colors.orange
                                        : Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                        // Direction indicator
                        Transform.rotate(
                          angle: _controller.currentBearing * 3.14159 / 180,
                          child: Container(
                            width: 44,
                            height: 44,
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
                              size: 20,
                            ),
                          ),
                        ),
                      ],
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
          child: _buildStatsCard(),
        ),

        // Control Buttons
        Positioned(
          bottom: 30,
          left: 16,
          right: 16,
          child: _buildControlButtons(),
        ),
      ],
    );
  }

  /// Build stats card showing distance, time, points
  Widget _buildStatsCard() {
    return Container(
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
                RouteHelpers.formatDistance(_controller.totalDistance / 1000),
                'Distance',
              ),
              _buildStat(
                Icons.access_time,
                RouteHelpers.formatTime(_controller.totalTime ~/ 60),
                'Time',
              ),
              _buildStat(
                Icons.my_location,
                '${_controller.recordedPoints.length}',
                'Points',
              ),
            ],
          ),
          if (_controller.currentAccuracy > 0) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.gps_fixed,
                  size: 16,
                  color: _controller.currentAccuracy < 10
                      ? Colors.green
                      : _controller.currentAccuracy < 20
                          ? Colors.orange
                          : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  'GPS Accuracy: ${_controller.currentAccuracy.toStringAsFixed(1)}m',
                  style: TextStyle(
                    fontSize: 12,
                    color: _controller.currentAccuracy < 10
                        ? Colors.green.shade700
                        : _controller.currentAccuracy < 20
                            ? Colors.orange.shade700
                            : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build control buttons (Start/Pause/Stop)
  Widget _buildControlButtons() {
    return Container(
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
          if (!_controller.isRecording)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleStartRecording,
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
          if (_controller.isRecording) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handlePauseResume,
                icon: Icon(_controller.isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(_controller.isPaused ? 'Resume' : 'Pause'),
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
                onPressed: _handleStopRecording,
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
    );
  }

  /// Build details view for adding route information
  Widget _buildDetailsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRouteNameCard(),
          const SizedBox(height: 16),
          _buildStatsInfoCard(),
          const SizedBox(height: 16),
          _buildImageCard(),
          const SizedBox(height: 16),
          _buildWaypointsCard(),
          const SizedBox(height: 24),
          _buildSaveButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Build route name input card
  Widget _buildRouteNameCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
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
    );
  }

  /// Build stats info card
  Widget _buildStatsInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
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
                  RouteHelpers.formatDistance(_controller.totalDistance / 1000),
                  'Distance',
                  Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  Icons.access_time,
                  RouteHelpers.formatTime(_controller.totalTime ~/ 60),
                  'Duration',
                  Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build image selection card
  Widget _buildImageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
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
          if (_controller.selectedImage != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_controller.selectedImage!.path),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _controller.removeImage(),
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
          if (_controller.selectedImage == null)
            GestureDetector(
              onTap: _handlePickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
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
    );
  }

  /// Build waypoints card
  Widget _buildWaypointsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
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
                onPressed: _handleAddWaypoint,
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
          if (_controller.waypoints.isEmpty)
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
          if (_controller.waypoints.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _controller.waypoints.length,
              itemBuilder: (context, index) {
                final waypoint = _controller.waypoints[index];
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
                    title: Text(waypoint.name),
                    subtitle: Text(
                      waypoint.question,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red.shade700,
                      onPressed: () => _controller.removeWaypoint(index),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Build save button
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _controller.isLoading ? null : _handleSaveRoute,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: primaryBlue.withOpacity(0.6),
        ),
        child: _controller.isLoading
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
    );
  }

  /// Build stat widget for recording view
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

  /// Build stat card for details view
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

  /// Card decoration helper
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

/// Quick dialog for adding waypoint at current location during recording
class _QuickWaypointDialog extends StatefulWidget {
  final LatLng currentLocation;
  final Function(Waypoint) onAdd;

  const _QuickWaypointDialog({
    required this.currentLocation,
    required this.onAdd,
  });

  @override
  State<_QuickWaypointDialog> createState() => _QuickWaypointDialogState();
}

class _QuickWaypointDialogState extends State<_QuickWaypointDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleAdd() {
    // Validate inputs
    if (_nameController.text.isEmpty || _questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in name and question'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final options = _optionControllers.map((c) => c.text).toList();
    if (options.any((o) => o.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all options'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create waypoint at current location
    final waypoint = Waypoint(
      name: _nameController.text,
      location: widget.currentLocation,
      question: _questionController.text,
      options: options,
      correctIndex: _correctIndex,
    );

    widget.onAdd(waypoint);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.add_location_alt, color: Color(0xFF3D5A80)),
          const SizedBox(width: 8),
          const Text('Add Waypoint Here'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current location: ${widget.currentLocation.latitude.toStringAsFixed(5)}, ${widget.currentLocation.longitude.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Waypoint name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Waypoint Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 12),

            // Quiz question
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Quiz Question',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.quiz),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Options
            const Text(
              'Options (select correct answer):',
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
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
        ElevatedButton.icon(
          onPressed: _handleAdd,
          icon: const Icon(Icons.check),
          label: const Text('Add Waypoint'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3D5A80),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
