import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_ext.dart';
import 'language_cubit.dart';

class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final options = _languageOptions(context.l10n);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.getString('language.pageTitle'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.getString('language.description'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: BlocBuilder<LanguageCubit, Locale>(
                  builder: (context, locale) {
                    return ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = _localeEquals(option.locale, locale);
                        return ListTile(
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selected
                                ? const Color(0xFF7FAC58)
                                : Colors.grey.shade400,
                          ),
                          title: Text(option.label),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF7FAC58),
                                )
                              : null,
                          onTap: () {
                            context.read<LanguageCubit>().setLocale(
                              option.locale,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _localeEquals(Locale a, Locale b) {
    return a.languageCode == b.languageCode &&
        (a.scriptCode ?? '') == (b.scriptCode ?? '') &&
        (a.countryCode ?? '') == (b.countryCode ?? '');
  }

  List<_LanguageOption> _languageOptions(AppLocalizations l10n) {
    return [
      _LanguageOption(
        locale: const Locale('en'),
        label: l10n.getString('language.english'),
      ),
      _LanguageOption(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
        label: l10n.getString('language.chineseTraditional'),
      ),
      _LanguageOption(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        label: l10n.getString('language.chineseSimplified'),
      ),
      _LanguageOption(
        locale: const Locale('ko'),
        label: l10n.getString('language.korean'),
      ),
      _LanguageOption(
        locale: const Locale('ja'),
        label: l10n.getString('language.japanese'),
      ),
      _LanguageOption(
        locale: const Locale('th'),
        label: l10n.getString('language.thai'),
      ),
      _LanguageOption(
        locale: const Locale('vi'),
        label: l10n.getString('language.vietnamese'),
      ),
    ];
  }
}

class _LanguageOption {
  _LanguageOption({required this.locale, required this.label});

  final Locale locale;
  final String label;
}
