import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../pin/pin_model.dart';
import '../../../services/mock_parking_service.dart';

class ParkingInfoSheet extends StatefulWidget {
  final String? id;
  final LatLng location;
  final double? occupancyPercent;
  final String? startTime;
  final String? endTime;
  final int? maximumStayMinutes;
  final String? description;

  const ParkingInfoSheet({
    super.key,
    required this.location,
    this.id,
    this.occupancyPercent,
    this.startTime,
    this.endTime,
    this.maximumStayMinutes,
    this.description,
  });

  @override
  State<ParkingInfoSheet> createState() => _ParkingInfoSheetState();
}

class _ParkingInfoSheetState extends State<ParkingInfoSheet> {
  late ParkingLocation parkingLocation;
  int selectedDay = DateTime.now().weekday; // 1=Monday, 7=Sunday
  int currentRestrictionIndex = 0;

  // Define the green color based on app theme
  static const Color primaryGreen = Color(0xFF7FAC58);
  static const Color lightGreen = Color.fromRGBO(127, 172, 88, 0.4);

  @override
  void initState() {
    super.initState();

    // USE MOCK DATA FOR TESTING MULTI-RESTRICTION UI
    // TODO: Set this to false when enhanced API is ready
    const bool useMockData = true;

    if (useMockData) {
      // Use mock data with multiple restrictions per day for testing
      parkingLocation = MockParkingService.getMockParkingLocation();
      // Debug: Using mock data with ${parkingLocation.restrictions.length} restrictions
    } else {
      // Use real API data (current single restriction) - TODO: Enable when API is enhanced
      final pin = Pin(
        id: widget.id,
        lat: widget.location.latitude,
        lng: widget.location.longitude,
        occupancyPercent: widget.occupancyPercent,
        startTime: widget.startTime,
        endTime: widget.endTime,
        maximumStayMinutes: widget.maximumStayMinutes,
        description: widget.description,
      );
      parkingLocation = ParkingLocation.fromPin(pin);
    }

    // CRITICAL FIX: Set currentRestrictionIndex to the currently active restriction
    _setInitialRestrictionIndex();
  }

  // Find and set the index of the currently active restriction
  void _setInitialRestrictionIndex() {
    final currentDayRestrictions = parkingLocation.getRestrictionsForDay(selectedDay);
    if (currentDayRestrictions.isEmpty) return;

    // Find the currently active restriction
    final now = DateTime.now();
    final currentTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    for (int i = 0; i < currentDayRestrictions.length; i++) {
      final restriction = currentDayRestrictions[i];

      // Parse restriction times
      final startParts = restriction.startTime.split(':');
      final endParts = restriction.endTime.split(':');

      var startTime = DateTime(now.year, now.month, now.day,
                               int.parse(startParts[0]), int.parse(startParts[1]));
      var endTime = DateTime(now.year, now.month, now.day,
                            int.parse(endParts[0]), int.parse(endParts[1]));

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
      final startTime = DateTime(now.year, now.month, now.day,
                                int.parse(startParts[0]), int.parse(startParts[1]));

      if (currentTime.isBefore(startTime)) {
        currentRestrictionIndex = i;
        return; // Found the next restriction
      }
    }

    // Fallback: stay at index 0 if no logic above applies
    currentRestrictionIndex = 0;
  }

  // Get day abbreviations
  List<String> get dayAbbreviations => ['MON', 'TUES', 'WED', 'THURS', 'FRI', 'SAT', 'SUN'];

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
        currentRestrictionIndex = (currentRestrictionIndex + 1) % restrictions.length;
      } else {
        currentRestrictionIndex = (currentRestrictionIndex - 1 + restrictions.length) % restrictions.length;
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important: minimize column size
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(), // Prevent bounce
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0), // Bottom padding for safe area
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
                                  margin: const EdgeInsets.only(left: 2, top: 2), // Reduced margins
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${currentRestrictionIndex + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
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
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
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
                              widget.description ?? 'Parking Location',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Restriction count badge - CENTERED
                      if (restrictions.isNotEmpty)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryGreen,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${restrictions.length} Restriction${restrictions.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Information blocks - improved proportions
                      if (restriction != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hours block - wider and flexible height
                            Expanded(
                              flex: 3,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 160, 
                                  maxHeight: 200, 
                                ),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: lightGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min, // Important: minimize size
                                  children: [
                                    const Text(
                                      'Hour',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Icon(
                                      Icons.access_time,
                                      size: 22,
                                      color: Colors.black54,
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
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
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

                            // Right column - FIXED layout cascade issue
                            Expanded(
                              flex: 2,
                              child: IntrinsicHeight( // CRITICAL: This fixes the layout cascade
                                child: Column(
                                  children: [
                                    // Max stay block - Safe fixed approach
                                    Flexible(
                                      fit: FlexFit.tight,
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: lightGreen,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Max stay',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black54,
                                              ),
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 2),
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
                                            const Text(
                                              'Mins',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.black54,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Occupancy block - Safe fixed approach
                                    Flexible(
                                      fit: FlexFit.tight,
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: lightGreen,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Occupacy',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black54,
                                              ),
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 2),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                restriction.occupancyPercent != null
                                                  ? '${(restriction.occupancyPercent! * 100).round()}'
                                                  : 'NA',
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const Text(
                                              '%',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.black54,
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
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Day selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(7, (index) {
                            final dayIndex = index + 1; // 1-7 for Monday-Sunday
                            final isSelected = dayIndex == selectedDay;
                            final isCurrentDay = dayIndex == currentDay;

                            return GestureDetector(
                              onTap: () => _selectDay(dayIndex),
                              child: Column(
                                children: [
                                  Text(
                                    dayAbbreviations[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? primaryGreen : Colors.black54,
                                    ),
                                  ),
                                  if (isCurrentDay)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      height: 3,
                                      width: 20,
                                      decoration: BoxDecoration(
                                        color: primaryGreen,
                                        borderRadius: BorderRadius.circular(1.5),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'select to see other day restrictions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
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
