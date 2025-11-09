import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_storage_service.dart';
import '../models/recorded_route.dart';

/// Service for syncing local routes to Firestore when online
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  /// Initialize sync service and start listening for connectivity changes
  Future<void> initialize() async {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final isConnected = results.any((result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet);

        if (isConnected && !_isSyncing) {
          // Connection available - try to sync
          syncPendingRoutes();
        }
      },
    );

    // Try initial sync if connected
    final connectivityResult = await _connectivity.checkConnectivity();
    final isConnected = connectivityResult.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    if (isConnected) {
      syncPendingRoutes();
    }
  }

  /// Check if device is currently connected to internet
  Future<bool> isConnected() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }

  /// Sync all pending routes to Firestore
  Future<SyncResult> syncPendingRoutes() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    _isSyncing = true;

    try {
      // Check if connected
      if (!await isConnected()) {
        _isSyncing = false;
        return SyncResult(
            success: false, message: 'No internet connection available');
      }

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isSyncing = false;
        return SyncResult(success: false, message: 'User not authenticated');
      }

      // Get pending routes
      final pendingRoutes = LocalStorageService.getPendingSyncRoutes();

      if (pendingRoutes.isEmpty) {
        _isSyncing = false;
        return SyncResult(success: true, message: 'No routes to sync', syncedCount: 0);
      }

      int successCount = 0;
      int failedCount = 0;
      String? lastError;

      // Sync each route
      for (final route in pendingRoutes) {
        try {
          final firestoreId = await _uploadRouteToFirestore(route);

          if (firestoreId != null) {
            // Mark as synced in local storage
            await LocalStorageService.markAsSynced(route.id!, firestoreId);
            successCount++;
          } else {
            failedCount++;
            lastError = 'Failed to upload route: ${route.roadName}';
          }
        } catch (e) {
          failedCount++;
          lastError = e.toString();
          print('Error syncing route ${route.roadName}: $e');
        }
      }

      _isSyncing = false;

      if (failedCount == 0) {
        return SyncResult(
          success: true,
          message: 'Successfully synced $successCount route(s)',
          syncedCount: successCount,
        );
      } else {
        return SyncResult(
          success: false,
          message:
              'Synced $successCount route(s), $failedCount failed. Error: $lastError',
          syncedCount: successCount,
          failedCount: failedCount,
        );
      }
    } catch (e) {
      _isSyncing = false;
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedCount: 0,
      );
    }
  }

  /// Upload a single route to Firestore
  Future<String?> _uploadRouteToFirestore(RecordedRoute route) async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('Guide')
          .add(route.toMap());

      return docRef.id;
    } catch (e) {
      print('Error uploading route to Firestore: $e');
      return null;
    }
  }

  /// Manual sync trigger (for user-initiated sync)
  Future<SyncResult> manualSync() async {
    return await syncPendingRoutes();
  }

  /// Get count of pending routes
  int getPendingCount() {
    return LocalStorageService.getPendingSyncCount();
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
  });
}
