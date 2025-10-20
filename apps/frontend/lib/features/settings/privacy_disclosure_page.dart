import 'package:flutter/material.dart';

/// Presents ParkPie's privacy commitments for both Apple and Android stores.
class PrivacyDisclosurePage extends StatelessWidget {
  const PrivacyDisclosurePage({super.key});

  Text _sectionTitle(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Disclosure')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ParkPie collects only the information required to deliver parking discovery, '
                'sign scanning, and parking reminder experiences. We align our disclosure with '
                'Apple’s App Store Privacy Nutrition Label guidance and Google Play’s Data Safety policy.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _sectionTitle(
                context,
                'Apple App Store (Privacy Nutrition Label)',
              ),
              const SizedBox(height: 12),
              _bullet(
                'We audit every ParkPie feature and each third-party SDK to declare the data types we '
                'collect and how we use them. This includes camera assets, coarse and precise location, '
                'diagnostics, and identifiers needed for sign ingestion and parking timers.',
              ),
              _bullet(
                'Any data transmitted off-device is linked to the user only when it is essential for core '
                'functionality (for example, associating parking sessions with an account). We never repurpose '
                'this data for tracking or third-party advertising.',
              ),
              _bullet(
                'If our practices change, we update App Store Connect immediately so the Privacy Label remains accurate. '
                'Optional data collection (feedback forms, support requests) is clearly opt-in and described in the UI.',
              ),
              _bullet(
                'When partner SDKs (such as camera, maps, analytics) process user data we review their manifests and include '
                'their behaviours in our disclosures, ensuring signatures and privacy manifests stay compliant.',
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Google Play (Data Safety)'),
              const SizedBox(height: 12),
              _bullet(
                'Our Google Play Data Safety form mirrors the Apple Privacy Label: we enumerate every data type collected, '
                'its purpose (app functionality, analytics, crash diagnostics), and whether it is shared.',
              ),
              _bullet(
                'We do not sell user data. Limited sharing occurs only with vetted processors that support sign recognition, '
                'mapping, and notification delivery, and they are bound by contractual privacy requirements.',
              ),
              _bullet(
                'Users can request data deletion or export at any time via in-app support or the Privacy Choices link on our store listings.',
              ),
              _bullet(
                'Location, sensor, and camera access stay off-device whenever possible. If data leaves the device, it is encrypted in transit '
                'and retained only as long as needed to service a parking session or comply with legal obligations.',
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Data Handling Principles'),
              const SizedBox(height: 12),
              _bullet(
                'Purpose limitation: data is collected strictly to deliver ParkPie experiences such as locating parking, interpreting signs, '
                'and running timers. Anything beyond that requires fresh consent.',
              ),
              _bullet(
                'Transparency: privacy links on both stores point to our full policy, explain optional data capture, and outline how third parties behave.',
              ),
              _bullet(
                'User control: permissions (camera, location, notifications, Bluetooth) remain optional and can be revoked in system settings without disabling account access.',
              ),
              _bullet(
                'Accuracy: we continuously monitor SDK manifests, privacy questionnaires, and legal changes to keep these disclosures up to date.',
              ),

              const SizedBox(height: 24),
              _sectionTitle(context, 'Need More Information?'),
              const SizedBox(height: 12),
              Text(
                'If you have questions about these practices or need to exercise your privacy rights, contact privacy@parkpie.com. '
                'We respond to requests within applicable regulatory timelines.',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
