// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ParkPie';

  @override
  String get contribute => 'Contribute';

  @override
  String get uploadSuccessful => 'Upload successful!';

  @override
  String get noPhotoCaptured => 'No photo captured';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get retake => 'Retake';

  @override
  String get useThisPhoto => 'Use This Photo';
}
