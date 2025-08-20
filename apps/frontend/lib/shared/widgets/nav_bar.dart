import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFEDEDED), // background color
      height: 70,
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
            label: 'Contribute',
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
            color: isSelected ? Colors.blue : Colors.black, // optional highlight
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Color(0xFF3A3A3C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}