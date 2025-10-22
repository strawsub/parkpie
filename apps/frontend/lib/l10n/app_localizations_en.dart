import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([super.locale = 'en']);

  static const Map<String, String> _localizedValues = {
    'appTitle': 'ParkPie',
    'contribute': 'Contribute',
    'scan': 'Scan',
    'uploadSuccessful': 'Upload successful!',
    'noPhotoCaptured': 'No photo captured',
    'takePhoto': 'Take Photo',
    'retake': 'Retake',
    'useThisPhoto': 'Use This Photo',
    'nav.parking': 'Parking',
    'nav.scan': 'Scan',
    'nav.timer': 'Timer',
    'settings.title': 'Settings',
    'camera.takePhotoHeader': 'TAKE PHOTO OF PARKING SIGN',
    'camera.instructions':
        'Point your camera at the parking sign and capture the full view',
    'camera.analyzing': 'Analyzing parking sign...',
    'camera.analyzingDetail':
        'Extracting text, summarising the rules and syncing with ParkPie.',
    'camera.analysisTitle': 'Sign Summary',
    'camera.zoneAdded': 'Zone Added',
    'camera.restrictionsSynced': '{count} restriction(s) synced',
    'camera.restrictionsReplaced': '{count} old restriction(s) replaced',
    'camera.aiExplanation': 'AI explanation',
    'camera.aiExplanationFallback':
        'AI could not summarise this sign. Please review the restrictions below.',
    'camera.locationLabel': 'Location',
    'camera.buttonRetake': 'Retake Photo',
    'camera.buttonDone': 'Done',
    'camera.storeMessage': 'Stored zone {zone} with {count} window(s).',
    'camera.updateMessage': 'Updated zone {zone} ({count} window(s) replaced).',
    'camera.manualZoneSaved': 'Manual zone {zone} saved to ParkPie.',
    'camera.errorTitle': 'We couldn\'t read that sign',
    'camera.errorBack': 'Back to map',
    'camera.errorMessage':
        'No nearby parking sign could be found. Please select a sign on the map or rescan the sign.',
    'camera.captureButton': 'Capture',
    'camera.retake': 'Retake photo',
    'language.settingsTitle': 'Language',
    'language.settingsSubtitle': 'Switch the app language',
    'language.pageTitle': 'Language',
    'language.description':
        'Choose the language used throughout ParkPie. Changes apply instantly.',
    'language.settingsAction': 'Choose language',
    'language.english': 'English',
    'language.chineseTraditional': 'Traditional Chinese',
    'language.chineseSimplified': 'Simplified Chinese',
    'language.korean': 'Korean',
    'language.japanese': 'Japanese',
    'language.thai': 'Thai',
    'language.vietnamese': 'Vietnamese',
    'privacy.settingsTitle': 'Privacy & Compliance',
    'privacy.settingsSubtitle':
        'Review how ParkPie discloses data practices for App Store Privacy Labels and Google Play Data Safety.',
    'privacy.settingsAction': 'View Privacy Disclosure',
  };

  static String lookupDefault(String key) => _localizedValues[key] ?? key;

  @override
  String getString(String key) => lookupDefault(key);
}
