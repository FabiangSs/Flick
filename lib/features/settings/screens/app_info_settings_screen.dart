import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/features/onboarding/screens/onboarding_screen.dart';
import 'package:flick/features/settings/screens/privacy_policy_screen.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';

class AppInfoSettingsScreen extends ConsumerStatefulWidget {
  const AppInfoSettingsScreen({super.key});

  @override
  ConsumerState<AppInfoSettingsScreen> createState() =>
      _AppInfoSettingsScreenState();
}

class _AppInfoSettingsScreenState extends ConsumerState<AppInfoSettingsScreen>
    with SingleTickerProviderStateMixin {
  static final Uri _releaseNotesApiUri = Uri.parse(
    'https://api.github.com/repos/ultraelectronica/flick_player/releases/latest',
  );
  static const String _releaseNotesUrl =
      'https://github.com/ultraelectronica/flick_player/releases/latest';

  bool _isCheckingForUpdates = false;
  bool _isInstallingUpdate = false;
  bool _hasScannedForUpdates = false;
  bool _updateAvailable = false;
  bool _updateDownloaded = false;
  String? _updateCheckErrorMessage;

  late final AnimationController _donationPulseController;
  late final Animation<double> _donationPulseAnimation;

  @override
  void initState() {
    super.initState();
    _donationPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _donationPulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _donationPulseController,
        curve: Curves.easeInOut,
      ),
    );
    _donationPulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _donationPulseController.dispose();
    super.dispose();
  }

  bool get _restartRequiredForUpdate => _updateDownloaded;

  bool get _hasAvailableUpdate => _updateAvailable;

  void _showToast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _scanForUpdates() async {
    if (_isCheckingForUpdates || _isInstallingUpdate) return;

    setState(() {
      _isCheckingForUpdates = true;
      _updateCheckErrorMessage = null;
    });

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!mounted) return;

      final hasUpdate =
          info.updateAvailability == UpdateAvailability.updateAvailable;
      final inProgress =
          info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress;

      setState(() {
        _hasScannedForUpdates = true;
        _updateAvailable = hasUpdate;
        _updateDownloaded = inProgress;
        _updateCheckErrorMessage = null;
      });

      if (hasUpdate) {
        _showToast('Update available.');
        return;
      }
      if (inProgress) {
        _showToast('Update already in progress.');
        return;
      }
      _showToast('No new update found.');
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _hasScannedForUpdates = true;
        _updateAvailable = false;
        _updateDownloaded = false;
        _updateCheckErrorMessage =
            'In-app updates only work when installed from the Play Store.';
      });
      _showToast('In-app updates require the Play Store version of the app.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasScannedForUpdates = true;
        _updateAvailable = false;
        _updateDownloaded = false;
        _updateCheckErrorMessage = 'Unable to reach the update service.';
      });
      _showToast('Failed to check for updates: $error');
    } finally {
      if (mounted) {
        setState(() => _isCheckingForUpdates = false);
      }
    }
  }

  Future<void> _installUpdate() async {
    if (_isInstallingUpdate) return;

    if (_restartRequiredForUpdate) {
      _showToast('Update finished. Restart the app to use it.');
      return;
    }

    if (!_hasAvailableUpdate) {
      _showToast(
        _hasScannedForUpdates
            ? 'No available update to install.'
            : 'Scan for updates first.',
      );
      return;
    }

    setState(() => _isInstallingUpdate = true);

    try {
      _showToast('Downloading update in the background. Keep using the app.');
      final result = await InAppUpdate.startFlexibleUpdate();
      if (!mounted) return;

      if (result == AppUpdateResult.success) {
        setState(() {
          _hasScannedForUpdates = true;
          _updateDownloaded = true;
          _updateAvailable = false;
          _updateCheckErrorMessage = null;
        });
        _showToast('Update downloaded. Restart the app to install.');
      } else if (result == AppUpdateResult.userDeniedUpdate) {
        _showToast('Update cancelled.');
      } else {
        _showToast('Update failed. Try again later.');
      }
    } catch (error) {
      if (!mounted) return;
      _showToast('Failed to install update: $error');
    } finally {
      if (mounted) {
        setState(() => _isInstallingUpdate = false);
      }
    }
  }

  ({IconData icon, String title, String subtitle}) _getUpdateStatusDetails() {
    if (_isCheckingForUpdates) {
      return (
        icon: LucideIcons.refreshCw,
        title: 'Checking for Updates',
        subtitle: 'Looking for a new update right now',
      );
    }
    if (_isInstallingUpdate) {
      return (
        icon: LucideIcons.download,
        title: 'Installing Update',
        subtitle: 'The download is running in the background',
      );
    }
    if (_restartRequiredForUpdate) {
      return (
        icon: LucideIcons.badgeCheck,
        title: 'Update Ready',
        subtitle: 'Restart the app to finish updating',
      );
    }
    if (_hasAvailableUpdate) {
      return (
        icon: LucideIcons.download,
        title: 'Update Available',
        subtitle: 'A new update is ready to download',
      );
    }
    if (_updateCheckErrorMessage != null) {
      return (
        icon: LucideIcons.info,
        title: 'Could Not Check for Updates',
        subtitle: _updateCheckErrorMessage!,
      );
    }
    if (_hasScannedForUpdates &&
        !_updateAvailable &&
        !_updateDownloaded &&
        _updateCheckErrorMessage == null) {
      return (
        icon: LucideIcons.badgeCheck,
        title: 'No Update Available',
        subtitle: 'You already have the latest update',
      );
    }
    return (
      icon: LucideIcons.info,
      title: 'No Update Scan Yet',
      subtitle: 'Run a manual scan to see whether an update is available',
    );
  }

  Widget _buildUpdateStatusTile() {
    final details = _getUpdateStatusDetails();
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          Container(
            width: context.scaleSize(AppConstants.containerSizeSm),
            height: context.scaleSize(AppConstants.containerSizeSm),
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(
              details.icon,
              color: context.adaptiveTextSecondary,
              size: context.responsiveIcon(AppConstants.iconSizeMd),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<_PatchNotes> _fetchPatchNotes() async {
    final response = await http.get(
      _releaseNotesApiUri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'FlickPlayer',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final title = (data['name'] as String?)?.trim();
    final tag = (data['tag_name'] as String?)?.trim();
    final body = (data['body'] as String?)?.trim();
    final htmlUrl = (data['html_url'] as String?)?.trim();

    return _PatchNotes(
      title: title?.isNotEmpty == true
          ? title!
          : tag?.isNotEmpty == true
          ? tag!
          : 'Latest Update',
      body: body?.isNotEmpty == true ? body! : 'No patch notes available yet.',
      url: htmlUrl?.isNotEmpty == true ? htmlUrl! : _releaseNotesUrl,
    );
  }

  void _showPatchNotesBottomSheet() {
    GlassBottomSheet.show(
      context: context,
      title: 'Patch Notes',
      maxHeightRatio: 0.7,
      content: FutureBuilder<_PatchNotes>(
        future: _fetchPatchNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.spacingLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppConstants.spacingMd),
                  const CircularProgressIndicator(color: AppColors.textPrimary),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    'Loading patch notes...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppConstants.spacingMd),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    'Unable to load patch notes right now.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _launchUrl(_releaseNotesUrl),
                    icon: const Icon(LucideIcons.externalLink),
                    label: const Text('Open Release Notes'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
              ],
            );
          }

          final notes = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppConstants.spacingMd),
                Text(
                  notes.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: SelectableText(
                    notes.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _launchUrl(notes.url),
                    icon: const Icon(LucideIcons.externalLink),
                    label: const Text('Open Full Notes'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAboutBottomSheet() {
    GlassBottomSheet.show(
      context: context,
      title: 'About Flick Player',
      maxHeightRatio: 0.5,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppConstants.spacingMd),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: SvgPicture.asset(
              'assets/icons/flicklogo_svg.svg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          const Text(
            'Flick Player',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Version 0.14.0-beta.1',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Text(
              'A premium music player with custom UAC 2.0 powered by Rust for the best audio experience.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _launchUrl(
                  'https://github.com/ultraelectronica/flick_player',
                ),
                icon: const Icon(LucideIcons.squareCode, size: 18),
                label: const Text(
                  'GitHub',
                  style: TextStyle(fontFamily: 'ProductSans'),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
        ],
      ),
    );
  }

  void _showLicensesBottomSheet() {
    const licenseContent = '''
MIT License

Copyright (c) 2026 Flick Player Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

    GlassBottomSheet.show(
      context: context,
      title: 'Licenses',
      maxHeightRatio: 0.7,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppConstants.spacingMd),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Text(
                licenseContent,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched && mounted) {
        _showToast('Could not open the link');
      }
    } catch (e) {
      if (mounted) {
        _showToast('Could not open the link: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'App Info',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Updates'),
          SettingsCard(
            children: [
              ActionButton(
                icon: LucideIcons.scanSearch,
                title: _isCheckingForUpdates
                    ? 'Scanning for Updates...'
                    : 'Scan for Updates',
                subtitle: _isCheckingForUpdates
                    ? 'Checking for the latest update now'
                    : 'Check manually whenever you want',
                onTap: _isCheckingForUpdates || _isInstallingUpdate
                    ? null
                    : _scanForUpdates,
              ),
              const SettingsDivider(),
              _buildUpdateStatusTile(),
              if (_hasAvailableUpdate || _restartRequiredForUpdate) ...[
                const SettingsDivider(),
                NavigationSetting(
                  icon: LucideIcons.fileText,
                  title: 'Patch Notes',
                  subtitle: 'See what is new in this update',
                  onTap: _showPatchNotesBottomSheet,
                ),
              ],
              if (_hasAvailableUpdate || _isInstallingUpdate) ...[
                const SettingsDivider(),
                ActionButton(
                  icon: LucideIcons.download,
                  title: _isInstallingUpdate
                      ? 'Installing Update...'
                      : 'Install Update',
                  subtitle: _isInstallingUpdate
                      ? 'Downloading in the background. Keep using the app'
                      : 'Download now and restart the app when it finishes',
                  onTap: _isInstallingUpdate ? null : _installUpdate,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('About'),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: LucideIcons.info,
                title: 'About Flick Player',
                subtitle: 'Version 0.14.0-beta.1',
                onTap: _showAboutBottomSheet,
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.fileText,
                title: 'Licenses',
                subtitle: 'Open source licenses',
                onTap: _showLicensesBottomSheet,
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.shieldCheck,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.sparkles,
                title: 'View Onboarding',
                subtitle: 'Replay the tutorial and feature guide',
                onTap: () {
                  ref.read(onboardingCompletedProvider.notifier).reset();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OnboardingScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Support'),
          AnimatedBuilder(
            animation: _donationPulseAnimation,
            builder: (context, child) {
              return SettingsCard(
                border: Border.all(
                  color: AppColors.textPrimary.withValues(
                    alpha: 0.25 + _donationPulseAnimation.value * 0.55,
                  ),
                  width: 1.0 + _donationPulseAnimation.value * 1.2,
                ),
                children: [
                  NavigationSetting(
                    icon: LucideIcons.heart,
                    title: 'Buy me a coffee',
                    subtitle: 'Support development on Ko-fi',
                    onTap: () =>
                        _launchUrl('https://ko-fi.com/ultraelectronica'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _PatchNotes {
  const _PatchNotes({
    required this.title,
    required this.body,
    required this.url,
  });

  final String title;
  final String body;
  final String url;
}
