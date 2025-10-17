import 'package:flutter/material.dart';

class ParkingDetectedBottomSheet extends StatefulWidget {
  final Function(int? selectedMinutes) onConfirm;
  final VoidCallback onCancel;

  const ParkingDetectedBottomSheet({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ParkingDetectedBottomSheet> createState() => _ParkingDetectedBottomSheetState();
}

class _ParkingDetectedBottomSheetState extends State<ParkingDetectedBottomSheet> {
  int? _selectedDuration; // null = count up, value = count down
  double _slidePosition = 0.0;
  static const double _slideThreshold = 0.75;
  static const Color _primaryGreen = Color(0xFF7FAC58);

  void _selectDuration(int minutes) {
    setState(() {
      _selectedDuration = _selectedDuration == minutes ? null : minutes;
    });
  }

  Widget _buildTimeDisplay() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'pm' : 'am';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$hour:$minute',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            period,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.normal,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'Parking Detected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Current Time Display
          _buildTimeDisplay(),
          const SizedBox(height: 16),

          // Description
          Text(
            'Select a time limit or ignore to use the nearest restriction',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Duration Selection Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDurationBadge('30 mins', 30),
              const SizedBox(width: 12),
              _buildDurationBadge('60 mins', 60),
              const SizedBox(width: 12),
              _buildDurationBadge('120 mins', 120),
            ],
          ),
          const SizedBox(height: 32),

          // Slide to Park Button
          _buildSlideToParButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDurationBadge(String label, int minutes) {
    final isSelected = _selectedDuration == minutes;
    return GestureDetector(
      onTap: () => _selectDuration(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildSlideToParButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonSize = 50.0;
    final containerPadding = 48.0; // 24px padding on each side
    final maxSlideDistance = screenWidth - containerPadding - buttonSize - 10; // 10px extra margin

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _slidePosition += details.delta.dx;
          _slidePosition = _slidePosition.clamp(0.0, maxSlideDistance);
        });

        // Auto-confirm when threshold reached
        if (_slidePosition >= maxSlideDistance * _slideThreshold) {
          widget.onConfirm(_selectedDuration);
        }
      },
      onHorizontalDragEnd: (details) {
        // Reset if not reached threshold
        if (_slidePosition < maxSlideDistance * _slideThreshold) {
          setState(() {
            _slidePosition = 0.0;
          });
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // Background text
            Center(
              child: Text(
                'Slide to Park',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Sliding button - centered vertically
            Positioned(
              left: _slidePosition + 5, // 5px left padding
              top: 5, // Center vertically: (60 - 50) / 2 = 5
              child: Container(
                height: buttonSize,
                width: buttonSize,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.keyboard_double_arrow_right,
                  size: 28,
                  color: _primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
