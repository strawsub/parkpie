import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:frontend/services/timer_service.dart';

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
  static const Color _primaryGreen = Color(0xFF7FAC58);

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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Select Parking Zone',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 8),
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

        const SizedBox(height: 8),

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
                      ? _primaryGreen
                      : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildZoneCard(ParkingZone zone, bool isClosest, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? _primaryGreen : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _primaryGreen.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        zone.formattedDistance,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
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
                        color: _primaryGreen,
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
                      color: _primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CLOSEST',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: _primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Selection checkmark
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: _primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
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
    );
  }

  Widget _buildNoZonesFound() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.location_off,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Parking Zones Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Could not find any parking zones nearby.\nYou can still start the timer without a zone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
