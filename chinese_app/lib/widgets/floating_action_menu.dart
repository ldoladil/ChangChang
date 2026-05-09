import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FloatingActionMenu extends StatefulWidget {
  final VoidCallback onManualEntry;
  final VoidCallback onScan;

  const FloatingActionMenu({
    super.key,
    required this.onManualEntry,
    required this.onScan,
  });

  @override
  State<FloatingActionMenu> createState() => _FloatingActionMenuState();
}

class _FloatingActionMenuState extends State<FloatingActionMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleScan() {
    try {
      HapticFeedback.lightImpact();
      _toggle();
      widget.onScan();
    } catch (e) {
      print("Error in onScan: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
    }
  }

  void _handleManualEntry() {
    try {
      HapticFeedback.lightImpact();
      _toggle();
      widget.onManualEntry();
    } catch (e) {
      print("Error in onManualEntry: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Option 1 : Scan (caméra)
        _buildAction(
          icon: Icons.camera_alt_outlined,
          label: 'Scanner',
          color: Colors.green.shade600,
          onPressed: _handleScan,
          offset: const Offset(-0.2, -1.6),
        ),
        // Option 2 : Saisie manuelle
        _buildAction(
          icon: Icons.edit_outlined,
          label: 'Saisie manuelle',
          color: Colors.orange.shade600,
          onPressed: _handleManualEntry,
          offset: const Offset(-1.2, -0.6),
        ),
        // Bouton principal (+)
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: const Color(0xFF1a73e8),
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close, // ← Fixed direction
            progress: _controller,
          ),
        ),
      ],
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required Offset offset,
  }) {
    return Positioned(
      bottom: 16.0 + (offset.dy * 56),
      right: 16.0 + (offset.dx * 56),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Tooltip(
          message: label,
          child: FloatingActionButton(
            onPressed: onPressed,
            backgroundColor: color,
            mini: true,
            child: Icon(icon, size: 24), // ← Simplified, no Column
          ),
        ),
      ),
    );
  }
}
