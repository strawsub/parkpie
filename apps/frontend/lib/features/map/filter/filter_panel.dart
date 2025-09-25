import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'filter_config.dart';

const String kFilterRequestPickOnMap = '__FILTER_PICK_ON_MAP__';

Future<Object?> showFilterSheet(BuildContext context, {FilterConfig? initial}) {
  final defaults =
      initial ??
      const FilterConfig(
        mode: LocationMode.current,
        selectedPoint: null,
        radiusMeters: 100,
        durationMinutes: 60,
        startTime: TimeOfDay(hour: 17, minute: 0),
      );

  return showModalBottomSheet<Object?>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(initial: defaults),
  );
}

class _FilterSheet extends StatefulWidget {
  final FilterConfig initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late LocationMode _mode;
  LatLng? _point;
  late double _radius;
  late TextEditingController _durationCtrl;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _point = widget.initial.selectedPoint;
    _radius = widget.initial.radiusMeters;
    _time = widget.initial.startTime;
    _durationCtrl = TextEditingController(
      text: widget.initial.durationMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final minutes = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    final cfg = FilterConfig(
      mode: _mode,
      selectedPoint: _mode == LocationMode.selected ? _point : null,
      radiusMeters: _radius,
      durationMinutes: minutes,
      startTime: _time,
    );
    Navigator.of(context).pop(cfg);
  }

  void _reset() {
    setState(() {
      _mode = LocationMode.current;
      _point = null;
      _radius = 100;
      _durationCtrl.text = '60';
      _time = const TimeOfDay(hour: 17, minute: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget locationSection() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Use current'),
                selected: _mode == LocationMode.current,
                onSelected: (_) => setState(() => _mode = LocationMode.current),
              ),
              ChoiceChip(
                label: const Text('Selected point'),
                selected: _mode == LocationMode.selected,
                onSelected: (_) {
                  if (_point == null) {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pop(kFilterRequestPickOnMap);
                  } else {
                    setState(() => _mode = LocationMode.selected);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Details card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _mode == LocationMode.current
                ? Row(
                    children: const [
                      Icon(Icons.my_location),
                      SizedBox(width: 8),
                      Text('Using device location'),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.location_on),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _point == null
                              ? 'No point selected'
                              : 'Lat: ${_point!.latitude.toStringAsFixed(6)} '
                                    'Lng: ${_point!.longitude.toStringAsFixed(6)}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(kFilterRequestPickOnMap),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Pick on map'),
                      ),
                    ],
                  ),
          ),
        ],
      );
    }

    final card = Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              locationSection(),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Radius (m)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _radius,
                      min: 0,
                      max: 300,
                      divisions: 30,
                      label: _radius.toStringAsFixed(0),
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      _radius.toStringAsFixed(0),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duration (min)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _durationCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: 'e.g. 60',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickTime,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time),
                                const SizedBox(width: 8),
                                Text(_time.format(context)),
                                const Spacer(),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton(onPressed: _reset, child: const Text('Reset')),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.65,
      snap: true,
      snapSizes: const [0.6, 0.65],
      expand: false,
      builder: (_, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          color: Theme.of(context).cardColor,
          child: SingleChildScrollView(controller: controller, child: card),
        ),
      ),
    );
  }
}
