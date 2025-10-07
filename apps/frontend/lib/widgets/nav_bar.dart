import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // get the bottom safe area padding
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(bottom: bottomPadding + 16, left: 20, right: 20),
      height: 70 + bottomPadding + 16,
      child: Center(
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                index: 0,
                iconPath: 'assets/parking_nav.svg',
                label: 'Parking',
              ),
              _buildNavItem(
                index: 1,
                iconPath: 'assets/contribute_nav.svg',
                label: 'Scan',
              ),
              _buildNavItem(
                index: 2,
                iconPath: 'assets/timer_nav.svg',
                label: 'Timer',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String iconPath,
    required String label,
  }) {
    final isSelected = index == currentIndex;
    final Color iconColor = isSelected ? const Color(0xFF7FAC58) : Colors.grey.shade600;
    final Color textColor = isSelected
        ? const Color(0xFF7FAC58)
        : Colors.grey.shade600;
    const double iconSize = 22;
    const double labelSpacing = 4;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            const SizedBox(height: labelSpacing),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.1,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
