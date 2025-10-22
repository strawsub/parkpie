import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:frontend/services/timer_service.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/spacing.dart';

class ParkingZoneCarousel extends StatefulWidget {
  final List<ParkingZone> parkingZones;
  final Function(ParkingZone) onZoneSelected;
  final ParkingZone? initialSelectedZone;
  final bool showTitle;

  const ParkingZoneCarousel({
    super.key,
    required this.parkingZones,
    required this.onZoneSelected,
    this.initialSelectedZone,
    this.showTitle = true,
  });

  @override
  State<ParkingZoneCarousel> createState() => _ParkingZoneCarouselState();
}

class _ParkingZoneCarouselState extends State<ParkingZoneCarousel> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialSelectedZone != null
        ? widget.parkingZones.indexOf(widget.initialSelectedZone!)
        : 0;
    if (_currentIndex < 0) _currentIndex = 0;

    // Notify parent of initial selection
    if (widget.parkingZones.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onZoneSelected(widget.parkingZones[_currentIndex]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.parkingZones.isEmpty) {
      return _buildNoZonesFound();
    }

    return Column(
      children: [
        // Title (optional)
        if (widget.showTitle) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.screenPadding),
            child: Text(
              'Select Parking Zone',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(height: Spacing.xs),
        ],

        // Carousel
        CarouselSlider.builder(
          itemCount: widget.parkingZones.length,
          options: CarouselOptions(
            height: 110,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            viewportFraction: 0.78,
            initialPage: _currentIndex,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
              widget.onZoneSelected(widget.parkingZones[index]);
            },
          ),
          itemBuilder: (context, index, realIndex) {
            final zone = widget.parkingZones[index];
            final isClosest = index == 0;
            final isCurrent = index == _currentIndex;

            return _buildZoneCard(zone, isClosest, isCurrent);
          },
        ),

        SizedBox(height: Spacing.xs),

        // Page indicator
        if (widget.parkingZones.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.parkingZones.asMap().entries.map((entry) {
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == entry.key
                      ? AppColors.primary
                      : AppColors.border,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildZoneCard(ParkingZone zone, bool isClosest, bool isCurrent) {
    return Semantics(
      label: 'Parking zone ${zone.zoneName ?? "Unknown"}, ${zone.formattedDistance} away, ${zone.formattedTimeLimit} time limit${isClosest ? ", closest zone" : ""}',
      selected: isCurrent,
      onTapHint: 'Double tap to select this zone',
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.borderLight,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: AppColors.scrim,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Stack(
        children: [
          // Main content - centered vertically
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with zone name
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          zone.zoneName ?? 'Parking Zone',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 50), // Space for badges in top right
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Distance
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        zone.formattedDistance,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Time limit
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        zone.formattedTimeLimit,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Top right badges row
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // CLOSEST badge
                if (isClosest) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                    child: Text(
                      'CLOSEST',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Selection checkmark
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildNoZonesFound() {
    return Container(
      padding: EdgeInsets.all(Spacing.screenPadding),
      child: Column(
        children: [
          Icon(
            Icons.location_off,
            size: 48,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: Spacing.md),
          Text(
            'No Parking Zones Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: Spacing.xs),
          Text(
            'Could not find any parking zones nearby.\nYou can still start the timer without a zone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: Spacing.lg),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement wider search or manual zone entry
            },
            icon: Icon(Icons.refresh),
            label: Text('Search Wider Area'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
