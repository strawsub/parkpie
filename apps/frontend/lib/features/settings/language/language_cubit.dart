import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';

class LanguageCubit extends Cubit<Locale> {
  LanguageCubit() : super(AppLocalizations.supportedLocales.first) {
    _loadLocale();
  }

  static const _prefsKey = 'app_locale';

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == null) return;

    final parsed = _deserialize(stored);
    if (_isSupported(parsed)) {
      emit(parsed);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale)) return;
    emit(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _serialize(locale));
  }

  bool _isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) =>
          supported.languageCode == locale.languageCode &&
          (supported.scriptCode == null ||
              supported.scriptCode == locale.scriptCode) &&
          (supported.countryCode == null ||
              supported.countryCode == locale.countryCode),
    );
  }

  String _serialize(Locale locale) {
    final buffer = StringBuffer(locale.languageCode);
    if (locale.scriptCode != null && locale.scriptCode!.isNotEmpty) {
      buffer.write('-${locale.scriptCode}');
    }
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      buffer.write('-${locale.countryCode}');
    }
    return buffer.toString();
  }

  Locale _deserialize(String tag) {
    final segments = tag.split('-');
    if (segments.isEmpty) {
      return AppLocalizations.supportedLocales.first;
    }
    if (segments.length == 1) {
      return Locale(segments[0]);
    }
    if (segments.length == 2) {
      final second = segments[1];
      if (second.length == 4) {
        return Locale.fromSubtags(
          languageCode: segments[0],
          scriptCode: second,
        );
      }
      return Locale(segments[0], second);
    }
    return Locale.fromSubtags(
      languageCode: segments[0],
      scriptCode: segments[1],
      countryCode: segments[2],
    );
  }
}
