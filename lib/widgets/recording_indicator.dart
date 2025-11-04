import 'package:flutter/material.dart';
import '../controllers/route_recording_controller.dart';
import '../screens/RecordRouteScreen.dart';

/// Global widget showing recording status
/// Can be placed in AppBar to show when recording is active
class RecordingIndicator extends StatelessWidget {
  const RecordingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RouteRecordingController();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (!controller.isRecording || controller.isFinished) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            // Navigate back to recording screen (remove current route first to avoid duplicates)
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const RecordRouteScreen(),
              ),
              (route) => route.isFirst, // Keep only the first route (main screen)
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: controller.isPaused
                  ? Colors.orange.shade700
                  : Colors.red.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing red dot
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                  onEnd: () {
                    // Restart animation
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  controller.isPaused ? 'Recording Paused' : 'Recording...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
