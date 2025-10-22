import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/widgets/navigation_cubit.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/services/timer_service.dart';
import 'package:frontend/services/api_config.dart';
import 'package:frontend/widgets/parking_zone_carousel.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/spacing.dart';
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
    final timerState = context.read<TimerBloc>().state;
    if (timerState is TimerRunning) {
      return;
    }

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
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
              padding: EdgeInsets.symmetric(
                horizontal: Spacing.xl,
                vertical: Spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: Spacing.xs),
                  _buildTitle(theme),
                  SizedBox(height: Spacing.lg),
                  _buildAnimation(),
                  SizedBox(height: Spacing.md),
                  // Add parking zone carousel
                  if (_isLoadingZones)
                    Padding(
                      padding: EdgeInsets.all(Spacing.md),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  else if (!_isLoadingZones && state is! TimerRunning) ...[
                    if (_nearbyZones != null && _nearbyZones!.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: Spacing.xl),
                        child: Text(
                          'Select parking zone',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(height: Spacing.xs),
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
                        padding: EdgeInsets.symmetric(horizontal: Spacing.xl),
                        child: Text(
                          'Swipe to select a zone',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      SizedBox(height: Spacing.md),
                    ],
                  ] else if (_nearbyZones != null && _nearbyZones!.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: Spacing.xl),
                      child: Text(
                        'No nearby parking zones found',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (_nearbyZones != null &&
                      _nearbyZones!.isEmpty &&
                      state is! TimerRunning)
                    SizedBox(height: Spacing.md),
                  if (failureState != null)
                    _buildFailureView(context, failureState, theme, colorScheme)
                  else ...[
                    if (state is TimerRunning)
                      _buildRestrictionCard(context, state, theme, colorScheme),
                    SizedBox(height: Spacing.md),
                    _buildButtons(context, state, colorScheme),
                  ],
                  // Add extra padding at bottom to ensure buttons are always visible
                  SizedBox(height: Spacing.huge),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Text(
      'Parking Timer',
      style: theme.textTheme.headlineMedium,
    );
  }

  Widget _buildAnimation() {
    return SizedBox(
      height: 240,
      child: Lottie.asset('assets/car-animate.json', fit: BoxFit.contain),
    );
  }

  Widget _buildFailureView(
    BuildContext context,
    TimerFailure state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final zoneLabel = state.zoneNumber != null
        ? 'Zone ${state.zoneNumber}'
        : 'this location';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
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
            color: AppColors.warning,
            size: 36,
          ),
          SizedBox(height: Spacing.sm),
          Text(
            "We couldn't find signage for $zoneLabel",
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.warningDark,
            ),
          ),
          SizedBox(height: Spacing.xxs + 2),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.warningDark,
            ),
          ),
          SizedBox(height: Spacing.md),
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
            ),
          ),
          SizedBox(height: Spacing.xs),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<NavigationCubit>().setIndex(1);
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Scan sign'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictionCard(
    BuildContext context,
    TimerState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
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

    final backgroundColor = isOvertime ? AppColors.errorLight : AppColors.surface;

    final borderColor = isOvertime ? AppColors.errorBorder : colorScheme.primary;

    final iconColor = isOvertime ? colorScheme.error : colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(Radii.card),
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
                  SizedBox(width: Spacing.xs),
                  Text(
                    'Parking Restriction',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  _showEditRestrictionDialog(context, restrictionMinutes);
                },
                padding: EdgeInsets.all(12),
                constraints: BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restriction',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    SizedBox(height: Spacing.xxs),
                    Text(
                      restrictionText,
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.border),
              SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOvertime ? 'Overtime' : 'Remaining',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    SizedBox(height: Spacing.xxs),
                    Text(
                      isOvertime ? '+$remainingText' : remainingText,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: isOvertime ? colorScheme.error : colorScheme.primary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
            borderRadius: BorderRadius.circular(Radii.modal),
          ),
          backgroundColor: AppColors.surface,
          contentPadding: const EdgeInsets.all(0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    Spacing.md,
                    Spacing.md,
                    Spacing.md,
                    Spacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Time Limit',
                        style: theme.textTheme.titleLarge,
                      ),
                      SizedBox(height: Spacing.xxs),
                      Text(
                        'Choose how long you can park here',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick presets
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'QUICK SELECT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: Spacing.xs),
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
                                  padding: EdgeInsets.symmetric(
                                    vertical: Spacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : AppColors.backgroundLight,
                                    borderRadius: BorderRadius.circular(Radii.chip),
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : AppColors.border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      preset['label'] as String,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: isSelected
                                            ? AppColors.surface
                                            : AppColors.textSecondary,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CUSTOM TIME',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: Spacing.xs),
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
                            padding: EdgeInsets.symmetric(horizontal: Spacing.xs),
                            child: Text(
                              ':',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: AppColors.textTertiary,
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
                  padding: EdgeInsets.fromLTRB(
                    Spacing.md,
                    Spacing.sm,
                    Spacing.md,
                    Spacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      SizedBox(width: Spacing.xs),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedMinutes > 0) {
                            context.read<TimerBloc>().add(
                              UpdateRestrictionDuration(selectedMinutes),
                            );
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        child: const Text('Save'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: AppColors.border),
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
                padding: EdgeInsets.symmetric(vertical: Spacing.xxs),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 20,
                  color: value + step <= maxValue
                      ? colorScheme.primary
                      : AppColors.border,
                ),
              ),
            ),
          ),
          // Value display
          Container(
            padding: EdgeInsets.symmetric(vertical: Spacing.xxs + 2),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: AppColors.border),
              ),
            ),
            child: Column(
              children: [
                Text(
                  value.toString().padLeft(2, '0'),
                  style: theme.textTheme.headlineMedium,
                ),
                SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
                padding: EdgeInsets.symmetric(vertical: Spacing.xxs),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: value - step >= 0
                      ? colorScheme.primary
                      : AppColors.border,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(
    BuildContext context,
    TimerState state,
    ColorScheme colorScheme,
  ) {
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
            color: isRunning ? AppColors.warning : colorScheme.primary,
            textColor: AppColors.surface,
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

        SizedBox(height: Spacing.xl),
      ],
    );
  }

  void _showResetConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.modal),
        ),
        backgroundColor: AppColors.surface,
        title: Text(
          'Stop Timer?',
          style: theme.textTheme.titleLarge,
        ),
        content: Text(
          'This will stop the timer and delete your parking session.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<TimerBloc>().add(const ResetTimer());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: AppColors.surface,
            ),
            child: const Text('Stop'),
          ),
        ],
        actionsPadding: EdgeInsets.fromLTRB(
          Spacing.md,
          0,
          Spacing.md,
          Spacing.md,
        ),
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
      height: TouchTargets.comfortable,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.modal),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              SizedBox(width: Spacing.xs),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}
