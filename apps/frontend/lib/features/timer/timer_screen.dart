import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/navigation/navigation_cubit.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/services/timer_service.dart';
import 'package:frontend/services/api_config.dart';
import 'package:frontend/widgets/parking_zone_carousel.dart';
import 'timer_bloc.dart';
import 'timer_event.dart';
import 'timer_state.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  List<ParkingZone>? _nearbyZones;
  bool _isLoadingZones = false;
  final TimerService _timerService = TimerService(
    backendBaseUrl: resolveApiBaseUrl(),
  );

  @override
  void initState() {
    super.initState();
    // Fetch zones when screen initializes
    _fetchNearbyZones();
  }

  Future<void> _fetchNearbyZones() async {
    setState(() {
      _isLoadingZones = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final zones = await _timerService.fetchNearbyParkingZones(
        lat: position.latitude,
        lng: position.longitude,
        radiusMeters: 100,
        maxResults: 5,
      );
      if (mounted) {
        setState(() {
          _nearbyZones = zones;
          _isLoadingZones = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nearbyZones = [];
          _isLoadingZones = false;
        });
      }
    }
  }

  void _onZoneSelected(ParkingZone zone, TimerState state) {
    // Only allow zone changes when timer is stopped
    if (state is! TimerRunning) {
      context.read<TimerBloc>().add(
        SetKnownZone(
          zoneNumber: zone.zoneNumber,
          zoneName: zone.zoneName ?? zone.zoneId,
        ),
      );

      // Update restriction duration based on zone's time limit
      if (zone.maximumStayMinutes != null && zone.maximumStayMinutes! > 0) {
        // Zone has a time limit - use it
        context.read<TimerBloc>().add(
          UpdateRestrictionDuration(zone.maximumStayMinutes!),
        );
      } else {
        // Zone has NO time limit - use -1 to indicate "no restriction" (different from null)
        context.read<TimerBloc>().add(UpdateRestrictionDuration(-1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocConsumer<TimerBloc, TimerState>(
          listener: (context, state) {
            if (state is TimerRunning && state.usingFallback) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Using cached restriction data. Timer may be inaccurate until the network returns.',
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            final failureState = state is TimerFailure ? state : null;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  _buildTitle(),
                  const SizedBox(height: 20),
                  _buildAnimation(),
                  const SizedBox(height: 16),
                  // Add parking zone carousel
                  if (_isLoadingZones)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7FAC58), // green spinner
                        ),
                      ),
                    )
                  else if (!_isLoadingZones && state is! TimerRunning) ...[
                    if (_nearbyZones != null && _nearbyZones!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Select parking zone',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ParkingZoneCarousel(
                        parkingZones: _nearbyZones!,
                        onZoneSelected: (zone) => _onZoneSelected(zone, state),
                        initialSelectedZone: _nearbyZones!.firstWhere(
                          (zone) => zone.zoneNumber == state.zoneNumber,
                          orElse: () => _nearbyZones!.first,
                        ),
                        showTitle: false,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Swipe to select a zone',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF7FAC58),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ] else if (_nearbyZones != null && _nearbyZones!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No nearby parking zones found',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  if (_nearbyZones != null &&
                      _nearbyZones!.isEmpty &&
                      state is! TimerRunning)
                    const SizedBox(height: 16),
                  if (failureState != null)
                    _buildFailureView(context, failureState)
                  else ...[
                    if (state is TimerRunning)
                      _buildRestrictionCard(context, state),
                    const SizedBox(height: 16),
                    _buildButtons(context, state),
                  ],
                  // Add extra padding at bottom to ensure buttons are always visible
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Parking Timer',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildAnimation() {
    return SizedBox(
      height: 240,
      child: Lottie.asset('assets/car-animate.json', fit: BoxFit.contain),
    );
  }

  Widget _buildTimerDisplay(TimerState state) {
    final elapsed = state.elapsed;
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);

    final timeString = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            color: Colors.grey.shade600,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailureView(BuildContext context, TimerFailure state) {
    final zoneLabel = state.zoneNumber != null
        ? 'Zone ${state.zoneNumber}'
        : 'this location';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade600,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            "We couldn't find signage for $zoneLabel",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<TimerBloc>().add(
                  StartTimer(
                    zoneNumber: state.zoneNumber,
                    zoneName: state.zoneName,
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry lookup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7FAC58),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<NavigationCubit>().setIndex(0);
                  },
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Choose on map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<NavigationCubit>().setIndex(1);
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Scan sign'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictionCard(BuildContext context, TimerState state) {
    final restrictionMinutes = state.restrictionDurationMinutes;
    final restrictionDuration = Duration(minutes: restrictionMinutes);

    final elapsed = state.elapsed;
    final remaining = restrictionDuration - elapsed;
    final isOvertime = remaining.isNegative;
    final displayRemaining = isOvertime ? -remaining : remaining;

    final remainingHours = displayRemaining.inHours;
    final remainingMinutes = displayRemaining.inMinutes.remainder(60);
    final remainingSeconds = displayRemaining.inSeconds.remainder(60);

    final restrictionHours = restrictionDuration.inHours;
    final restrictionMins = restrictionDuration.inMinutes.remainder(60);

    final restrictionText = restrictionHours > 0
        ? '${restrictionHours}h ${restrictionMins}m'
        : '${restrictionMins}m';

    final remainingText = remainingHours > 0
        ? '${remainingHours}h ${remainingMinutes}m ${remainingSeconds}s'
        : '${remainingMinutes}m ${remainingSeconds}s';

    final backgroundColor = isOvertime ? const Color(0x1AFF4757) : Colors.white;

    final borderColor = isOvertime
        ? const Color(0x4DFF4757)
        : Color(0xFF7FAC58);

    final iconColor = isOvertime ? const Color(0xFFFF4757) : Color(0xFF7FAC58);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOvertime ? Icons.warning_rounded : Icons.timer_outlined,
                    color: iconColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Parking Restriction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.edit, size: 20, color: Colors.grey.shade600),
                onPressed: () {
                  _showEditRestrictionDialog(context, restrictionMinutes);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restriction',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restrictionText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOvertime ? 'Overtime' : 'Remaining',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOvertime ? '+$remainingText' : remainingText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isOvertime
                            ? const Color(0xFFFF4757)
                            : const Color(0xFF7FAC58),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditRestrictionDialog(BuildContext context, int currentMinutes) {
    const primaryGreen = Color(0xFF7FAC58);
    int selectedMinutes = currentMinutes;

    // Common preset durations
    final presets = [
      {'label': '15 min', 'minutes': 15},
      {'label': '30 min', 'minutes': 30},
      {'label': '1 hour', 'minutes': 60},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Time Limit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose how long you can park here',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick presets
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'QUICK SELECT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: presets.asMap().entries.map((entry) {
                          final preset = entry.value;
                          final index = entry.key;
                          final isSelected =
                              selectedMinutes == preset['minutes'];
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: index == 0 ? 0 : 3,
                                right: index == presets.length - 1 ? 0 : 3,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedMinutes = preset['minutes'] as int;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryGreen
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryGreen
                                          : Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      preset['label'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Custom time picker
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CUSTOM TIME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Hours selector
                          Expanded(
                            child: _buildNumberPicker(
                              label: 'Hours',
                              value: selectedMinutes ~/ 60,
                              maxValue: 12,
                              onChanged: (hours) {
                                setState(() {
                                  selectedMinutes =
                                      (hours * 60) + (selectedMinutes % 60);
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              ':',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          // Minutes selector
                          Expanded(
                            child: _buildNumberPicker(
                              label: 'Minutes',
                              value: selectedMinutes % 60,
                              maxValue: 55,
                              step: 5,
                              onChanged: (mins) {
                                setState(() {
                                  selectedMinutes =
                                      (selectedMinutes ~/ 60) * 60 + mins;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedMinutes > 0) {
                            context.read<TimerBloc>().add(
                              UpdateRestrictionDuration(selectedMinutes),
                            );
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPicker({
    required String label,
    required int value,
    required int maxValue,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Increment button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (value + step <= maxValue) {
                  onChanged(value + step);
                }
              },
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 20,
                  color: value + step <= maxValue
                      ? const Color(0xFF7FAC58)
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
          // Value display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                Text(
                  value.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Decrement button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (value - step >= 0) {
                  onChanged(value - step);
                }
              },
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: value - step >= 0
                      ? const Color(0xFF7FAC58)
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context, TimerState state) {
    if (state is TimerFailure) {
      return const SizedBox.shrink();
    }
    final isRunning = state is TimerRunning;

    return Column(
      children: [
        // Start / Stop button
        SizedBox(
          width: double.infinity,
          child: _buildButton(
            label: isRunning ? 'Stop Timer' : 'Start Timer',
            color: isRunning ? Colors.orange : const Color(0xFF7FAC58),
            textColor: Colors.white,
            icon: isRunning
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            onPressed: isRunning
                ? () {
                    // Show confirmation dialog before stopping
                    _showResetConfirmation(context);
                  }
                : () {
                    context.read<TimerBloc>().add(const StartTimer());
                  },
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'Stop Timer?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: const Text(
          'This will stop the timer and delete your parking session.',
          style: TextStyle(fontSize: 15, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<TimerBloc>().add(const ResetTimer());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4757),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Stop',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required Color textColor,
    IconData? icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
