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
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF7FAC58),
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/parking_nav.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              currentIndex == 0 ? const Color(0xFF7FAC58) : Colors.grey.shade600,
              BlendMode.srcIn,
            ),
          ),
          label: 'Parking',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/contribute_nav.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              currentIndex == 1 ? const Color(0xFF7FAC58) : Colors.grey.shade600,
              BlendMode.srcIn,
            ),
          ),
          label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/timer_nav.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              currentIndex == 2 ? const Color(0xFF7FAC58) : Colors.grey.shade600,
              BlendMode.srcIn,
            ),
          ),
          label: 'Timer',
        ),
      ],
    );
  }
}
