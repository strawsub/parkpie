import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'timer_bloc.dart';
import 'timer_event.dart';
import 'timer_state.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocBuilder<TimerBloc, TimerState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  _buildTitle(),
                  const SizedBox(height: 20),
                  _buildAnimation(),
                  const SizedBox(height: 20),
                  _buildTimerDisplay(state),
                  const SizedBox(height: 16),
                  if (state.zoneNumber != null) _buildZoneInfo(state),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 90),
                    child: _buildButtons(context, state),
                  ),
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
      'Start Park Time Tracking',
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
      child: Lottie.asset(
        'assets/car-animate.json',
        fit: BoxFit.contain,
      ),
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

  Widget _buildZoneInfo(TimerState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF7FAC58).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7FAC58).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: const Color(0xFF7FAC58),
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.zoneName ?? 'Zone ${state.zoneNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7FAC58),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Check parking restrictions for this zone',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context, TimerState state) {
    final isRunning = state is TimerRunning;
    final isStopped = state is TimerStopped;

    return Row(
      children: [
        Expanded(
          child: _buildButton(
            label: 'Start',
            color: const Color(0xFF7FAC58),
            textColor: Colors.white,
            onPressed: isRunning
                ? null
                : () => _showStartDialog(context),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildButton(
            label: isStopped ? 'Reset' : 'End',
            color: const Color(0xFFFF4757),
            textColor: Colors.white,
            onPressed: (isRunning || isStopped)
                ? () {
                    if (isRunning) {
                      context.read<TimerBloc>().add(const StopTimer());
                    } else if (isStopped) {
                      context.read<TimerBloc>().add(const ResetTimer());
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required Color textColor,
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
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TEST ZONE DIALOG - FOR DEVELOPMENT/TESTING ONLY
  // ============================================================================
  // This dialog allows manual testing of zone info display without needing
  // to trigger actual parking detection (which requires driving around).
  //
  // 🗑️ TO REMOVE THIS TEST FEATURE:
  // 1. Delete this entire _showStartDialog() method
  // 2. In _buildButtons() above (line ~161), replace:
  //    onPressed: isRunning ? null : () => _showStartDialog(context),
  //    with:
  //    onPressed: isRunning ? null : () {
  //      context.read<TimerBloc>().add(const StartTimer());
  //    },
  //
  // Once removed, the Start button will directly start the timer without
  // showing the test zone dialog. Real zone info will only come from
  // automatic parking detection (ParkingBloc in main.dart).
  // ============================================================================
  void _showStartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start Timer'),
        content: const Text(
          'Would you like to add test parking zone information?\n\n'
          '(This simulates parking detection for testing)',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Start without zone info
              context.read<TimerBloc>().add(const StartTimer());
            },
            child: const Text('Start Without Zone'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Start with test zone info
              context.read<TimerBloc>().add(
                    const StartTimer(
                      zoneNumber: -9999,
                      zoneName: 'Test Zone - 2P (Mon-Fri 9AM-5PM)',
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7FAC58),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start With Test Zone'),
          ),
        ],
      ),
    );
  }
}
