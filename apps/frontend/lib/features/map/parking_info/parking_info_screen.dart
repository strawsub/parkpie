import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class ParkingInfoSheet extends StatelessWidget {
  final LatLng location;
  final double? occupancyPercent;
  final String? startTime;
  final String? endTime;
  final int? maximumStayMinutes;
  final String? description;

  const ParkingInfoSheet({
    super.key,
    required this.location,
    this.occupancyPercent,
    this.startTime,
    this.endTime,
    this.maximumStayMinutes,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5, // initial height as % of screen
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
          ),
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on),
                    // title: Text('${location.latitude}, ${location.longitude}'),
                    title: const Text('Location'),
                    subtitle: Text('$description'),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parking Restrictions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (occupancyPercent != null)
                          Text(
                            'Occupancy: ${occupancyPercent!.toStringAsFixed(1)}%',
                          ),
                        if (startTime != null && endTime != null)
                          Text('Hours: $startTime - $endTime'),
                        if (maximumStayMinutes != null)
                          Text('Max Stay: $maximumStayMinutes min'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('Last Updated'),
                        subtitle: Text(DateTime.now().toString()),
                      ),
                      ListTile(
                        leading: const Icon(Icons.verified_user),
                        title: const Text('Verified'),
                        trailing: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
