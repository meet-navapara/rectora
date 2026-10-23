import 'package:flutter/material.dart';
import 'package:rectora/domain/account/auth_types.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/domain/settings/settings.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/controller.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/about_page.dart';
import 'package:rectora/ui/screens/help_page.dart';
import 'package:rectora/ui/screens/privacy_page.dart';
import 'package:rectora/ui/screens/terms_page.dart';
import 'package:rectora/ui/widgets/dialogs.dart';
import 'package:rectora/ui/widgets/mark.dart';

const rectoraVersion = '1.0.0';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.activeLevelId, this.onResetLevel});

  final String? activeLevelId;
  final Future<void> Function()? onResetLevel;

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final settings = controller.save.settings;
    final palette = RectoraTheme.of(context);
    final save = controller.save;
    final signedIn = !save.isGuest;
    final stats = controller.stats;
    final solved =
        stats.parcelsSolved +
        stats.threadsSolved +
        stats.tracesSolved +
        stats.inksSolved;
    final puzzleTotal =
        controller.catalog.parcels.length +
        controller.catalog.threads.length +
        controller.catalog.traces.length +
        controller.catalog.inks.length;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          const _Heading('Account'),
          _Panel(
            child: Row(
              children: [
                AvatarMark(index: save.profile.avatar, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signedIn
                            ? (save.accountEmail?.isNotEmpty == true
                                  ? save.accountEmail!
                                  : save.accountName?.isNotEmpty == true
                                  ? save.accountName!
                                  : 'Google account')
                            : 'Guest account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        signedIn ? _accountLines(controller) : 'Saved on this phone. It does not follow you to another device.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Panel(
            child: Column(
              children: [
                _StatRow(label: 'Solved', value: '$solved / $puzzleTotal'),
                Divider(height: 1, color: palette.line.withValues(alpha: 0.5)),
                _StatRow(label: 'Mastery', value: '${save.xp}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!signedIn)
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: palette.pine,
                foregroundColor: const Color(0xFF10210E),
                shape: const StadiumBorder(),
              ),
              onPressed: controller.authBusy
                  ? null
                  : () => controller.signInWithGoogle(),
              child: controller.authBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in with Google'),
            )
          else ...[
            if (save.isGoogle && controller.cloud.configured)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: controller.syncBusy || controller.authBusy
                      ? null
                      : () => controller.syncNow(),
                  child: Text(controller.syncBusy ? 'Syncing' : 'Sync now'),
                ),
              ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: palette.pine,
                side: BorderSide(color: palette.pine, width: 1.4),
                shape: const StadiumBorder(),
              ),
              onPressed: controller.authBusy
                  ? null
                  : () async {
                      final choice = await showRectoraDialog<bool>(
                        context: context,
                        title: 'Sign out?',
                        body: 'Solved puzzles stay on this device. Progress stored with the Google account stays there and can be loaded again by signing in.',
                        choices: const [
                          DialogChoice(
                            label: 'Sign out',
                            value: true,
                            primary: true,
                          ),
                          DialogChoice(label: 'Cancel', value: false),
                        ],
                      );
                      if (choice == true) await controller.signOutAccount();
                    },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
          if (controller.accountMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              controller.accountMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: controller.accountMessageIsError
                    ? palette.rose
                    : palette.ink,
              ),
            ),
          ],
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: palette.rose,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => _clearLocalData(context, controller),
              child: const Text(
                'Clear local data on this device',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const _Heading('Audio & feel'),
          _Panel(
            child: Column(
              children: [
                _Toggle(
                  title: 'Sound effects',
                  value: settings.sound,
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(sound: value),
                  ),
                ),
                _Toggle(
                  title: 'Haptics',
                  value: settings.haptics,
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(haptics: value),
                  ),
                ),
                _Toggle(
                  title: 'Reduced motion',
                  subtitle: 'Fewer fades and moving accents',
                  value: !settings.animations,
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(animations: !value),
                  ),
                ),
                _Toggle(
                  title: 'Show timer',
                  value: settings.showTimer,
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(showTimer: value),
                  ),
                ),
                _Toggle(
                  title: 'Show size',
                  value: settings.showSize,
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(showSize: value),
                  ),
                ),
                _Toggle(
                  title: 'Place from the corner',
                  value: settings.cornerPlacement,
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(cornerPlacement: value),
                  ),
                ),
              ],
            ),
          ),
          const _Heading('Appearance'),
          _Panel(
            child: SegmentedButton<ThemeChoice>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return palette.pine.withValues(alpha: 0.28);
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.all(palette.ink),
                side: WidgetStateProperty.all(BorderSide.none),
              ),
              segments: const [
                ButtonSegment(value: ThemeChoice.dark, label: Text('Dark')),
                ButtonSegment(value: ThemeChoice.light, label: Text('Light')),
                ButtonSegment(value: ThemeChoice.system, label: Text('System')),
              ],
              selected: {settings.theme},
              onSelectionChanged: (value) {
                controller.updateSettings(
                  settings.copyWith(theme: value.first),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text('Board', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final style in boardStyles)
                ChoiceChip(
                  label: Text(
                    style.xpRequired == 0
                        ? style.title
                        : '${style.title} · ${style.xpRequired}',
                  ),
                  selected: settings.boardStyle == style.id,
                  onSelected: styleUnlocked(controller.save.xp, style.id)
                      ? (_) => controller.updateSettings(
                          settings.copyWith(boardStyle: style.id),
                        )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.save.xp} mastery points. Board styles unlock as you finish puzzles. They do not change the rules.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const _Heading('Help and privacy'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('How to play'),
            onTap: () => pushSoft(context, const HelpPage()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Replay tutorials'),
            subtitle: const Text(
              'Show the lessons again. Solved puzzles stay saved.',
            ),
            onTap: () async {
              await controller.replayTutorials();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tutorials will show again.')),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Privacy policy'),
            onTap: () => pushSoft(context, const PrivacyPage()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Terms and conditions'),
            onTap: () => pushSoft(context, const TermsPage()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('About RECTORA'),
            subtitle: const Text('Version $rectoraVersion'),
            onTap: () => pushSoft(context, const AboutPage()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Rectora',
              applicationVersion: rectoraVersion,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reset current level'),
            subtitle: Text(
              activeLevelId == null && save.lastPlayed == null
                  ? 'There is no active puzzle to reset.'
                  : 'Clears the current attempt.',
            ),
            enabled: onResetLevel != null || save.lastPlayed != null,
            onTap: () async {
              if (onResetLevel != null) {
                Navigator.pop(context);
                await onResetLevel!();
                return;
              }
              final id = controller.save.lastPlayed;
              if (id == null) return;
              final choice = await showRectoraDialog<bool>(
                context: context,
                title: 'Reset this level?',
                body: 'The saved attempt for $id will be cleared.',
                choices: const [
                  DialogChoice(label: 'Reset', value: true, primary: true),
                  DialogChoice(label: 'Cancel', value: false),
                ],
              );
              if (choice == true) {
                await controller.saveDraft(id: id, draft: null);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remove cloud data'),
            subtitle: const Text(
              'Deletes the progress stored for this Google account. The Google login stays. Puzzles on this phone stay until you clear them.',
            ),
            onTap: controller.syncBusy
                ? null
                : () => _removeCloudData(context, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _clearLocalData(
    BuildContext context,
    RectoraController controller,
  ) async {
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: 'Clear local data on this device?',
      body: 'Solved levels, streaks, drafts, and lesson progress on this phone will be removed. Settings, your display name, and the Google login stay. Cloud data is not deleted. Syncing again can bring a cloud copy back.',
      choices: const [
        DialogChoice(label: 'Clear local data', value: true, primary: true),
        DialogChoice(label: 'Cancel', value: false),
      ],
    );
    if (choice == true) await controller.clearProgress();
  }

  Future<void> _removeCloudData(
    BuildContext context,
    RectoraController controller,
  ) async {
    if (controller.save.isGuest) {
      await showRectoraDialog<bool>(
        context: context,
        title: 'Sign in to remove cloud data',
        body: 'Cloud progress belongs to a Google account. Sign in with that account, then choose Remove cloud data again. Puzzles on this phone are not deleted.',
        choices: const [DialogChoice(label: 'OK', value: true, primary: true)],
      );
      return;
    }
    if (!controller.cloud.configured) {
      await showRectoraDialog<bool>(
        context: context,
        title: 'Cloud data cannot be removed',
        body: 'This build has no cloud service. Progress on this phone was not deleted.',
        choices: const [DialogChoice(label: 'OK', value: true, primary: true)],
      );
      return;
    }
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: 'Remove cloud data?',
      body: 'This deletes the progress stored in the cloud for this Google account. The Google login stays, so you can sign in again. Puzzles on this phone stay until you clear them.',
      choices: const [
        DialogChoice(label: 'Remove cloud data', value: true, primary: true),
        DialogChoice(label: 'Cancel', value: false),
      ],
    );
    if (choice == true) await controller.deleteAccount();
  }

  String _accountLines(RectoraController controller) {
    final save = controller.save;
    final lines = <String>[
      if (save.isGoogle &&
          save.accountName != null &&
          save.accountName!.isNotEmpty)
        save.accountName!,
      if (save.isGoogle &&
          save.accountEmail != null &&
          save.accountEmail!.isNotEmpty)
        save.accountEmail!,
      if (save.isPlayGames) 'A Play Games id is stored on this device. Google sign-in is a separate step and is not connected yet.',
      syncPhaseLabel(controller.syncPhase),
    ];
    final stamp = formatSyncStamp(save.lastSyncAt);
    if (stamp != null) lines.add('Last sync $stamp');
    return lines.join('\n');
  }
}

String? formatSyncStamp(String? raw) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = parsed.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute';
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Material(
      color: palette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.line.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: child,
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: palette.muted)),
      value: value,
      activeThumbColor: palette.pine,
      onChanged: onChanged,
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: palette.copper, fontWeight: FontWeight.w700),
      ),
    );
  }
}
