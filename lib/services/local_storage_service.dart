import 'package:hive_flutter/hive_flutter.dart';
import '../models/recorded_route.dart';
import '../models/waypoint.dart';
import 'package:latlong2/latlong.dart';

/// Local storage service for offline-first route saving
/// Routes are saved locally first, then synced to Firestore when online
class LocalStorageService {
  static const String _routesBoxName = 'recorded_routes';
  static const String _pendingSyncBoxName = 'pending_sync';

  /// Initialize Hive local storage
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters for custom types
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RecordedRouteAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WaypointAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(LatLngAdapter());
    }

    // Open boxes
    await Hive.openBox<RecordedRoute>(_routesBoxName);
    await Hive.openBox<String>(_pendingSyncBoxName);
  }

  /// Save route locally
  static Future<String> saveRouteLocally(RecordedRoute route) async {
    final box = Hive.box<RecordedRoute>(_routesBoxName);

    // Generate unique ID using timestamp
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    // Save route with ID
    final routeWithId = RecordedRoute(
      id: id,
      roadName: route.roadName,
      totalDistance: route.totalDistance,
      totalTime: route.totalTime,
      recordedPoints: route.recordedPoints,
      waypoints: route.waypoints,
      imageUrl: route.imageUrl,
      createdBy: route.createdBy,
      createdAt: route.createdAt,
      isSynced: false, // Mark as not synced
    );

    await box.put(id, routeWithId);

    // Add to pending sync queue
    final pendingBox = Hive.box<String>(_pendingSyncBoxName);
    await pendingBox.add(id);

    return id;
  }

  /// Get all locally saved routes
  static List<RecordedRoute> getAllRoutes() {
    final box = Hive.box<RecordedRoute>(_routesBoxName);
    return box.values.toList();
  }

  /// Get routes that need syncing
  static List<RecordedRoute> getPendingSyncRoutes() {
    final box = Hive.box<RecordedRoute>(_routesBoxName);
    final pendingBox = Hive.box<String>(_pendingSyncBoxName);

    final pendingRoutes = <RecordedRoute>[];
    for (final id in pendingBox.values) {
      final route = box.get(id);
      if (route != null && !route.isSynced) {
        pendingRoutes.add(route);
      }
    }

    return pendingRoutes;
  }

  /// Mark route as synced
  static Future<void> markAsSynced(String routeId, String firestoreId) async {
    final box = Hive.box<RecordedRoute>(_routesBoxName);
    final route = box.get(routeId);

    if (route != null) {
      // Update route with Firestore ID and synced status
      final syncedRoute = RecordedRoute(
        id: firestoreId, // Use Firestore ID
        roadName: route.roadName,
        totalDistance: route.totalDistance,
        totalTime: route.totalTime,
        recordedPoints: route.recordedPoints,
        waypoints: route.waypoints,
        imageUrl: route.imageUrl,
        createdBy: route.createdBy,
        createdAt: route.createdAt,
        isSynced: true,
      );

      // Delete old entry
      await box.delete(routeId);

      // Save with new ID
      await box.put(firestoreId, syncedRoute);

      // Remove from pending sync
      final pendingBox = Hive.box<String>(_pendingSyncBoxName);
      final keyToDelete = pendingBox.keys.firstWhere(
        (key) => pendingBox.get(key) == routeId,
        orElse: () => null,
      );
      if (keyToDelete != null) {
        await pendingBox.delete(keyToDelete);
      }
    }
  }

  /// Delete route from local storage
  static Future<void> deleteRoute(String routeId) async {
    final box = Hive.box<RecordedRoute>(_routesBoxName);
    await box.delete(routeId);

    // Remove from pending sync if exists
    final pendingBox = Hive.box<String>(_pendingSyncBoxName);
    final keyToDelete = pendingBox.keys.firstWhere(
      (key) => pendingBox.get(key) == routeId,
      orElse: () => null,
    );
    if (keyToDelete != null) {
      await pendingBox.delete(keyToDelete);
    }
  }

  /// Get count of pending syncs
  static int getPendingSyncCount() {
    final pendingBox = Hive.box<String>(_pendingSyncBoxName);
    return pendingBox.length;
  }

  /// Clear all local data (use with caution)
  static Future<void> clearAll() async {
    final box = Hive.box<RecordedRoute>(_routesBoxName);
    final pendingBox = Hive.box<String>(_pendingSyncBoxName);

    await box.clear();
    await pendingBox.clear();
  }
}

/// Hive adapter for RecordedRoute
class RecordedRouteAdapter extends TypeAdapter<RecordedRoute> {
  @override
  final int typeId = 0;

  @override
  RecordedRoute read(BinaryReader reader) {
    return RecordedRoute(
      id: reader.read() as String?,
      roadName: reader.read() as String,
      totalDistance: reader.read() as double,
      totalTime: reader.read() as int,
      recordedPoints: (reader.read() as List).cast<LatLng>(),
      waypoints: (reader.read() as List).cast<Waypoint>(),
      imageUrl: reader.read() as String?,
      createdBy: reader.read() as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.read() as int),
      isSynced: reader.read() as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, RecordedRoute obj) {
    writer.write(obj.id);
    writer.write(obj.roadName);
    writer.write(obj.totalDistance);
    writer.write(obj.totalTime);
    writer.write(obj.recordedPoints);
    writer.write(obj.waypoints);
    writer.write(obj.imageUrl);
    writer.write(obj.createdBy);
    writer.write(obj.createdAt.millisecondsSinceEpoch);
    writer.write(obj.isSynced);
  }
}

/// Hive adapter for Waypoint
class WaypointAdapter extends TypeAdapter<Waypoint> {
  @override
  final int typeId = 1;

  @override
  Waypoint read(BinaryReader reader) {
    return Waypoint(
      name: reader.read() as String,
      location: reader.read() as LatLng,
      question: reader.read() as String,
      options: (reader.read() as List).cast<String>(),
      correctIndex: reader.read() as int,
    );
  }

  @override
  void write(BinaryWriter writer, Waypoint obj) {
    writer.write(obj.name);
    writer.write(obj.location);
    writer.write(obj.question);
    writer.write(obj.options);
    writer.write(obj.correctIndex);
  }
}

/// Hive adapter for LatLng
class LatLngAdapter extends TypeAdapter<LatLng> {
  @override
  final int typeId = 2;

  @override
  LatLng read(BinaryReader reader) {
    final lat = reader.read() as double;
    final lng = reader.read() as double;
    return LatLng(lat, lng);
  }

  @override
  void write(BinaryWriter writer, LatLng obj) {
    writer.write(obj.latitude);
    writer.write(obj.longitude);
  }
}
