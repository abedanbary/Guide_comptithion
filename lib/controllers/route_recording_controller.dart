import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import '../models/waypoint.dart';
import '../models/recorded_route.dart';
import '../config/cloudinary_config.dart';

/// Controller for managing route recording business logic
class RouteRecordingController extends ChangeNotifier {
  // Recording state
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isFinished = false;

  // Route data
  List<LatLng> _recordedPoints = [];
  LatLng? _currentLocation;
  LatLng? _previousLocation; // For calculating bearing
  double _totalDistance = 0.0; // in meters
  int _totalTime = 0; // in seconds
  DateTime? _startTime;
  double _currentBearing = 0.0; // Direction of movement in degrees
  double _currentAccuracy = 0.0; // GPS accuracy in meters

  // Waypoints and image
  List<Waypoint> _waypoints = [];
  XFile? _selectedImage;

  // Loading state
  bool _isLoading = false;
  String? _errorMessage;

  // Streams
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;

  // Getters
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  bool get isFinished => _isFinished;
  List<LatLng> get recordedPoints => List.unmodifiable(_recordedPoints);
  LatLng? get currentLocation => _currentLocation;
  double get totalDistance => _totalDistance;
  int get totalTime => _totalTime;
  List<Waypoint> get waypoints => List.unmodifiable(_waypoints);
  XFile? get selectedImage => _selectedImage;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get currentBearing => _currentBearing;
  double get currentAccuracy => _currentAccuracy;

  /// Initialize location and get current position
  Future<bool> initializeLocation() async {
    _errorMessage = null;
    notifyListeners();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorMessage = 'Please enable location services';
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMessage = 'Location permission denied';
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _errorMessage = 'Location permission permanently denied';
      notifyListeners();
      return false;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      _currentAccuracy = position.accuracy;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error getting location: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start recording the route
  void startRecording() {
    _isRecording = true;
    _isPaused = false;
    _startTime = DateTime.now();
    _recordedPoints.clear();
    _totalDistance = 0.0;
    _totalTime = 0;
    _errorMessage = null;
    notifyListeners();

    // Start timer for elapsed time
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording && !_isPaused) {
        _totalTime++;
        notifyListeners();
      }
    });

    // Start GPS tracking with high accuracy
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // Record every 2 meters for better accuracy
      ),
    ).listen(
      (Position position) {
        // Always update current location and accuracy for display
        _currentAccuracy = position.accuracy;

        // Only record points when actively recording (not paused)
        if (_isRecording && !_isPaused) {
          final newPoint = LatLng(position.latitude, position.longitude);

          // Calculate bearing (direction) if we have a previous location
          if (_currentLocation != null) {
            _currentBearing = Geolocator.bearingBetween(
              _currentLocation!.latitude,
              _currentLocation!.longitude,
              newPoint.latitude,
              newPoint.longitude,
            );
          }

          // Calculate distance from last recorded point
          if (_recordedPoints.isNotEmpty) {
            final lastPoint = _recordedPoints.last;
            final distance = Geolocator.distanceBetween(
              lastPoint.latitude,
              lastPoint.longitude,
              newPoint.latitude,
              newPoint.longitude,
            );

            // Only add point if moved enough and accuracy is good (< 20m)
            if (distance >= 1.5 && position.accuracy < 20) {
              _totalDistance += distance;
              _recordedPoints.add(newPoint);
            }
          } else {
            // First point - always add if accuracy is good
            if (position.accuracy < 20) {
              _recordedPoints.add(newPoint);
            }
          }

          _previousLocation = _currentLocation;
          _currentLocation = newPoint;
          notifyListeners();
        } else if (_isRecording && _isPaused) {
          // When paused, update display location but don't record
          _currentLocation = LatLng(position.latitude, position.longitude);
          notifyListeners();
        }
      },
      onError: (error) {
        _errorMessage = 'GPS tracking error: $error';
        notifyListeners();
      },
    );
  }

  /// Pause or resume recording
  void togglePause() {
    _isPaused = !_isPaused;
    notifyListeners();
  }

  /// Stop recording
  bool stopRecording() {
    if (_recordedPoints.length < 2) {
      _errorMessage = 'Record at least a short route before stopping';
      notifyListeners();
      return false;
    }

    _isRecording = false;
    _isPaused = false;
    _isFinished = true;
    _positionStream?.cancel();
    _timer?.cancel();
    notifyListeners();
    return true;
  }

  /// Add a waypoint to the route
  void addWaypoint(Waypoint waypoint) {
    _waypoints.add(waypoint);
    notifyListeners();
  }

  /// Add a waypoint at current location during recording
  void addWaypointAtCurrentLocation(Waypoint waypoint) {
    if (_currentLocation != null) {
      _waypoints.add(waypoint);
      notifyListeners();
    }
  }

  /// Check if can add waypoint (has current location)
  bool get canAddWaypoint => _currentLocation != null;

  /// Remove a waypoint by index
  void removeWaypoint(int index) {
    if (index >= 0 && index < _waypoints.length) {
      _waypoints.removeAt(index);
      notifyListeners();
    }
  }

  /// Pick an image for the route
  Future<bool> pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        _selectedImage = image;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error selecting image: $e';
      notifyListeners();
      return false;
    }
  }

  /// Remove selected image
  void removeImage() {
    _selectedImage = null;
    notifyListeners();
  }

  /// Upload image to Cloudinary
  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

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

    return response.secureUrl;
  }

  /// Save the route to Firestore
  Future<bool> saveRoute(String roadName) async {
    if (roadName.isEmpty) {
      _errorMessage = 'Please enter a route name';
      notifyListeners();
      return false;
    }

    if (_waypoints.isEmpty) {
      _errorMessage = 'Please add at least one waypoint with quiz';
      notifyListeners();
      return false;
    }

    if (_recordedPoints.length < 2) {
      _errorMessage = 'Route is too short';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
      }

      // Create route object
      final route = RecordedRoute(
        roadName: roadName,
        routePolyline: _recordedPoints,
        totalDistance: _totalDistance,
        totalTime: _totalTime,
        waypoints: _waypoints,
        imageUrl: imageUrl,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('roads')
          .add(route.toMap());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error saving route: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reset all data
  void reset() {
    _isRecording = false;
    _isPaused = false;
    _isFinished = false;
    _recordedPoints.clear();
    _currentLocation = null;
    _previousLocation = null;
    _totalDistance = 0.0;
    _totalTime = 0;
    _startTime = null;
    _currentBearing = 0.0;
    _currentAccuracy = 0.0;
    _waypoints.clear();
    _selectedImage = null;
    _isLoading = false;
    _errorMessage = null;
    _positionStream?.cancel();
    _timer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
