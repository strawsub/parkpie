import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/spacing.dart';
import '../pin/pin_model.dart';
import '../../../services/mock_parking_service.dart';

class ParkingInfoSheet extends StatefulWidget {
  final Pin pin;

  const ParkingInfoSheet({super.key, required this.pin});

  @override
  State<ParkingInfoSheet> createState() => _ParkingInfoSheetState();
}

class _ParkingInfoSheetState extends State<ParkingInfoSheet> {
  late ParkingLocation parkingLocation;
  int selectedDay = DateTime.now().weekday; // 1=Monday, 7=Sunday
  int currentRestrictionIndex = 0;

  @override
  void initState() {
    super.initState();

    final bool useMockData = MockParkingService.useMockData;

    parkingLocation = useMockData
        ? MockParkingService.getMockParkingLocation()
        : ParkingLocation.fromPin(widget.pin);

    selectedDay = _resolveInitialDay(DateTime.now().weekday);
    _setInitialRestrictionIndex();
  }

  int _resolveInitialDay(int preferredDay) {
    final availableDays = {
      for (final restriction in parkingLocation.restrictions)
        restriction.dayOfWeek,
    };

    if (availableDays.isEmpty) {
      return preferredDay;
    }

    if (availableDays.contains(preferredDay)) {
      return preferredDay;
    }

    final sorted = availableDays.toList()..sort();
    return sorted.first;
  }

  // Find and set the index of the currently active restriction
  void _setInitialRestrictionIndex() {
    final currentDayRestrictions = parkingLocation.getRestrictionsForDay(
      selectedDay,
    );
    if (currentDayRestrictions.isEmpty) return;

    // Find the currently active restriction
    final now = DateTime.now();
    final currentTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );

    for (int i = 0; i < currentDayRestrictions.length; i++) {
      final restriction = currentDayRestrictions[i];

      // Parse restriction times
      final startParts = restriction.startTime.split(':');
      final endParts = restriction.endTime.split(':');

      var startTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );
      var endTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );

      // Handle overnight restrictions (end time next day)
      if (endTime.isBefore(startTime)) {
        endTime = endTime.add(const Duration(days: 1));
      }

      // Check if current time falls within this restriction
      if (currentTime.isAfter(startTime) && currentTime.isBefore(endTime)) {
        currentRestrictionIndex = i;
        return; // Found the active restriction!
      }
    }

    // If no restriction is currently active, find the next upcoming one
    for (int i = 0; i < currentDayRestrictions.length; i++) {
      final restriction = currentDayRestrictions[i];
      final startParts = restriction.startTime.split(':');
      final startTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );

      if (currentTime.isBefore(startTime)) {
        currentRestrictionIndex = i;
        return; // Found the next restriction
      }
    }

    // Fallback: stay at index 0 if no logic above applies
    currentRestrictionIndex = 0;
  }

  // Get day abbreviations
  List<String> get dayAbbreviations => [
    'MON',
    'TUES',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  // Get current restrictions for selected day
  List<ParkingRestriction> get currentDayRestrictions {
    return parkingLocation.getRestrictionsForDay(selectedDay);
  }

  // Get current restriction being displayed
  ParkingRestriction? get currentRestriction {
    final restrictions = currentDayRestrictions;
    if (restrictions.isEmpty) return null;
    if (currentRestrictionIndex >= restrictions.length) {
      currentRestrictionIndex = 0;
    }
    return restrictions[currentRestrictionIndex];
  }

  // Check if showing current restriction
  bool get isShowingCurrentRestriction {
    final currentDay = DateTime.now().weekday;
    if (selectedDay != currentDay) return false;

    final current = parkingLocation.currentRestriction;
    if (current == null) return false;

    final displaying = currentRestriction;
    return displaying != null &&
        displaying.dayOfWeek == current.dayOfWeek &&
        displaying.startTime == current.startTime &&
        displaying.endTime == current.endTime;
  }

  // Get header text based on current state
  String get headerText {
    if (isShowingCurrentRestriction) {
      return 'Current Restriction';
    } else if (selectedDay == DateTime.now().weekday) {
      return 'Next Restriction';
    } else {
      return '${dayAbbreviations[selectedDay - 1]} Restriction';
    }
  }

  void _navigateRestriction(bool forward) {
    final restrictions = currentDayRestrictions;
    if (restrictions.isEmpty) return;

    setState(() {
      if (forward) {
        currentRestrictionIndex =
            (currentRestrictionIndex + 1) % restrictions.length;
      } else {
        currentRestrictionIndex =
            (currentRestrictionIndex - 1 + restrictions.length) %
            restrictions.length;
      }
    });
  }

  void _selectDay(int dayOfWeek) {
    setState(() {
      selectedDay = dayOfWeek;
      currentRestrictionIndex = 0; // Reset to first restriction of the day
    });
  }

  @override
  Widget build(BuildContext context) {
    final restriction = currentRestriction;
    final restrictions = currentDayRestrictions;
    final currentDay = DateTime.now().weekday;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
            boxShadow: [BoxShadow(blurRadius: 10, color: AppColors.shadow)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important: minimize column size
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: Spacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(), // Prevent bounce
                  padding: const EdgeInsets.fromLTRB(
                    16.0,
                    0,
                    16.0,
                    24.0,
                  ), // Bottom padding for safe area
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Minimize column size
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Center(
                        child: Text(
                          headerText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Day and navigation row
                      Row(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dayAbbreviations[selectedDay - 1],
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                              ),
                              if (restrictions.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(
                                    left: 4,
                                    top: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${currentRestrictionIndex + 1}/${restrictions.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),

                          // Navigation arrow
                          if (restrictions.length > 1)
                            IconButton(
                              onPressed: () => _navigateRestriction(true),
                              icon: const Icon(Icons.arrow_forward_ios),
                              iconSize: 20,
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Location with parking icon
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(Spacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              'P',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              parkingLocation.description ??
                                  widget.pin.description ??
                                  'Parking Location',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Information blocks - NEW LAYOUT WITH RESTRICTION BADGE
                      if (restriction != null)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Hours block - LEFT SIDE (matches right column height)
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(Radii.card),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Hour',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: Lottie.asset(
                                          'assets/Waiting.json',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        restriction.formattedStartTime,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        height: 2,
                                        width: 25,
                                        margin: EdgeInsets.symmetric(
                                          vertical: Spacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.textSecondary,
                                          borderRadius: BorderRadius.circular(1),
                                        ),
                                      ),
                                      Text(
                                        restriction.formattedEndTime,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Right column - RESTRICTION BADGE + MAX STAY + OCCUPANCY
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    // Restriction count badge at top
                                    if (restrictions.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Spacing.sm,
                                          vertical: Spacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            Radii.card,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${restrictions.length} Restriction${restrictions.length > 1 ? 's' : ''}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 8),

                                    // Max stay block
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Spacing.sm,
                                          vertical: Spacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            Radii.card,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Max stay',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 4),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '${restriction.maximumStayMinutes}',
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Mins',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Occupancy block
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Spacing.sm,
                                          vertical: Spacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            Radii.card,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Occupancy',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 4),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                restriction.occupancyPercent !=
                                                        null
                                                    ? '${(restriction.occupancyPercent! * 100).round()}'
                                                    : 'NA',
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '%',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // No restrictions message - centered with consistent spacing
                      if (restriction == null)
                        SizedBox(
                          height: 210, // Match approximate height of restriction info blocks
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'No Restrictions for ${dayAbbreviations[selectedDay - 1]}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'There are no parking restrictions recorded for this day.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Day selector
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(7, (index) {
                            final dayIndex = index + 1; // 1-7 for Monday-Sunday
                            final isSelected = dayIndex == selectedDay;
                            final isCurrentDay = dayIndex == currentDay;

                            return Semantics(
                              label: '${['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][index]}${isCurrentDay ? ', today' : ''}',
                              selected: isSelected,
                              button: true,
                              onTapHint: 'Double tap to view restrictions',
                              child: GestureDetector(
                                onTap: () => _selectDay(dayIndex),
                                child: Column(
                                  children: [
                                    Text(
                                      dayAbbreviations[index],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    if (isCurrentDay)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        height: 3,
                                        width: 20,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(1.5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),

                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'select to see other day restrictions',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
