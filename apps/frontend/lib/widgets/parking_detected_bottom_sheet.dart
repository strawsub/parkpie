import 'package:flutter/material.dart';
import 'package:frontend/widgets/parking_zone_carousel.dart';
import 'package:frontend/services/timer_service.dart';
import 'package:geolocator/geolocator.dart';

class ParkingDetectedBottomSheet extends StatefulWidget {
  final Function(int? selectedMinutes, ParkingZone? selectedZone) onConfirm;
  final VoidCallback onCancel;
  final TimerService timerService;

  const ParkingDetectedBottomSheet({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    required this.timerService,
  });

  @override
  State<ParkingDetectedBottomSheet> createState() => _ParkingDetectedBottomSheetState();
}

class _ParkingDetectedBottomSheetState extends State<ParkingDetectedBottomSheet> {
  int? _selectedDuration; // null = count up, value = count down
  double _slidePosition = 0.0;
  static const double _slideThreshold = 0.75;
  static const Color _primaryGreen = Color(0xFF7FAC58);

  List<ParkingZone>? _nearbyZones;
  ParkingZone? _selectedZone;
  bool _isLoadingZones = true;

  @override
  void initState() {
    super.initState();
    _fetchNearbyZones();
  }

  Future<void> _fetchNearbyZones() async {
    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Fetch nearby parking zones
      final zones = await widget.timerService.fetchNearbyParkingZones(
        lat: position.latitude,
        lng: position.longitude,
        radiusMeters: 100,
        maxResults: 5,
      );

      if (mounted) {
        setState(() {
          _nearbyZones = zones;
          _selectedZone = zones.isNotEmpty ? zones.first : null;
          _isLoadingZones = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching nearby zones: $e');
      if (mounted) {
        setState(() {
          _nearbyZones = [];
          _isLoadingZones = false;
        });
      }
    }
  }

  void _selectDuration(int minutes) {
    setState(() {
      _selectedDuration = _selectedDuration == minutes ? null : minutes;
      // Manual override takes priority - disable zone selection
    });
  }

  void _onZoneSelected(ParkingZone zone) {
    // Only update selected zone if no manual override is active
    if (_selectedDuration == null) {
      setState(() {
        _selectedZone = zone;
      });
    }
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // Current Time Display
          _buildTimeDisplay(),
          const SizedBox(height: 16),

          // Description
          Text(
            _isLoadingZones
                ? 'Loading nearby parking zones...'
                : _selectedDuration != null
                    ? 'Using manual override: ${_selectedDuration} minutes'
                    : 'Select a parking zone or manually override the time limit',
            style: TextStyle(
              fontSize: 11,
              color: _selectedDuration != null ? _primaryGreen : Colors.grey.shade600,
              fontWeight: _selectedDuration != null ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Parking Zone Carousel
          if (_isLoadingZones)
            const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  color: _primaryGreen,
                ),
              ),
            )
          else if (_nearbyZones != null && _nearbyZones!.isNotEmpty)
            Opacity(
              opacity: _selectedDuration != null ? 0.4 : 1.0,
              child: IgnorePointer(
                ignoring: _selectedDuration != null,
                child: ParkingZoneCarousel(
                  parkingZones: _nearbyZones!,
                  onZoneSelected: _onZoneSelected,
                  initialSelectedZone: _selectedZone,
                ),
              ),
            )
          else
            Container(
              height: 150,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.location_off,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No parking zones found nearby',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Duration Override Badges (Optional)
          if (_selectedZone != null)
            Column(
              children: [
                Text(
                  'Or manually set time limit',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDurationBadge('30 min', 30),
                    const SizedBox(width: 12),
                    _buildDurationBadge('60 min', 60),
                    const SizedBox(width: 12),
                    _buildDurationBadge('120 min', 120),
                  ],
                ),
                if (_selectedDuration != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Zone selection disabled',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),

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
          widget.onConfirm(_selectedDuration, _selectedZone);
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
          color: _primaryGreen,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // Background text
            Center(
              child: Text(
                'Slide to Park',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
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
