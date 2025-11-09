import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/local_storage_service.dart';
import 'dart:async';

/// Widget that shows sync status and pending route count
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  final SyncService _syncService = SyncService();
  int _pendingCount = 0;
  bool _isSyncing = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updatePendingCount();

    // Update every 5 seconds
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _updatePendingCount();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _updatePendingCount() {
    setState(() {
      _pendingCount = _syncService.getPendingCount();
    });
  }

  Future<void> _handleManualSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    final result = await _syncService.manualSync();

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      _updatePendingCount();

      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if no pending routes
    if (_pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _handleManualSync,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            if (_isSyncing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              )
            else
              Icon(
                Icons.cloud_upload_outlined,
                color: Colors.orange.shade700,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSyncing
                        ? 'جاري المزامنة...'
                        : '$_pendingCount طريق بانتظار المزامنة',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isSyncing
                        ? 'يتم رفع الطرق إلى السحابة'
                        : 'اضغط للمزامنة الآن',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isSyncing)
              Icon(
                Icons.touch_app,
                color: Colors.orange.shade700,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
