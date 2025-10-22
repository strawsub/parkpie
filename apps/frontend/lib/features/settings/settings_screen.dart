import 'package:flutter/material.dart';
import 'package:frontend/features/settings/language/language_selection_page.dart';
import 'package:frontend/features/settings/privacy_disclosure_page.dart';
import 'package:frontend/l10n/app_localizations_ext.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/spacing.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.getString('settings.title')),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(Spacing.screenPadding),
        children: [
          // Language Settings Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: Spacing.sm),
                      Text(
                        context.l10n.getString('language.settingsTitle'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Spacing.xs),
                  Padding(
                    padding: EdgeInsets.only(left: 32),
                    child: Text(
                      context.l10n.getString('language.settingsSubtitle'),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(height: Spacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LanguageSelectionPage(),
                          ),
                        );
                      },
                      child: Text(
                        context.l10n.getString('language.settingsAction'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: Spacing.md),

          // Privacy Disclaimer Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: Spacing.sm),
                      Text(
                        context.l10n.getString('privacy.settingsTitle'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Spacing.xs),
                  Padding(
                    padding: EdgeInsets.only(left: 32),
                    child: Text(
                      context.l10n.getString('privacy.settingsSubtitle'),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(height: Spacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyDisclosurePage(),
                          ),
                        );
                      },
                      child: Text(
                        context.l10n.getString('privacy.settingsAction'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: Spacing.lg),

          // App Information
          Center(
            child: Column(
              children: [
                Text(
                  'ParkPie',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: Spacing.xxs),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
