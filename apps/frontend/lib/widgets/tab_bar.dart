import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/l10n/app_localizations_ext.dart';

class BottomTabBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: theme.textTheme.bodySmall?.color,
      selectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      items: [
        BottomNavigationBarItem(
          icon: Semantics(
            label: 'Parking map tab',
            selected: currentIndex == 0,
            child: SvgPicture.asset(
              'assets/parking_nav.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                currentIndex == 0
                    ? colorScheme.primary
                    : theme.textTheme.bodySmall!.color!,
                BlendMode.srcIn,
              ),
            ),
          ),
          label: context.l10n.getString('nav.parking'),
        ),
        BottomNavigationBarItem(
          icon: Semantics(
            label: 'Scan parking sign tab',
            selected: currentIndex == 1,
            child: SvgPicture.asset(
              'assets/contribute_nav.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                currentIndex == 1
                    ? colorScheme.primary
                    : theme.textTheme.bodySmall!.color!,
                BlendMode.srcIn,
              ),
            ),
          ),
          label: context.l10n.getString('nav.scan'),
        ),
        BottomNavigationBarItem(
          icon: Semantics(
            label: 'Parking timer tab',
            selected: currentIndex == 2,
            child: SvgPicture.asset(
              'assets/timer_nav.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                currentIndex == 2
                    ? colorScheme.primary
                    : theme.textTheme.bodySmall!.color!,
                BlendMode.srcIn,
              ),
            ),
          ),
          label: context.l10n.getString('nav.timer'),
        ),
      ],
    );
  }
}
