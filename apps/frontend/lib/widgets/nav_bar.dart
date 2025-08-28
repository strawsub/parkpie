import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // get the bottom safe area padding
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: const Color(0xFFEDEDED),
      padding: EdgeInsets.only(bottom: bottomPadding),
      height: 70 + bottomPadding, 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
        ],
      ),
    );
  }

  Widget _buildNavItem({required int index, required String iconPath, required String label}) {
    final isSelected = index == currentIndex;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            color: isSelected ? const Color(0xFF016C34) : Colors.black, // optional highlight
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF3A3A3C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
