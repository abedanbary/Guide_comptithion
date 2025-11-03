import 'package:flutter/material.dart';
import 'dart:io';

/// Custom loading indicator using the app icon
/// Shows a pulsing animation with the app icon
class AppLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? backgroundColor;

  const AppLoadingIndicator({
    super.key,
    this.size = 80,
    this.backgroundColor,
  });

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3D5A80).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipOval(
            child: _buildIcon(),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    // Check if icon.png exists in assets
    final iconPath = 'assets/icon.png';

    // Try to load from assets, fallback to default icon
    return Image.asset(
      iconPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to default hiking icon
        return Container(
          color: const Color(0xFF3D5A80),
          child: Icon(
            Icons.terrain,
            size: widget.size * 0.6,
            color: const Color(0xFFE9C46A),
          ),
        );
      },
    );
  }
}

/// Compact version for smaller loading states
class AppLoadingSmall extends StatelessWidget {
  final double size;

  const AppLoadingSmall({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to spinning circle
          return CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          );
        },
      ),
    );
  }
}
