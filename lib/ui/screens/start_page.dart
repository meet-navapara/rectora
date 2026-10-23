import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/privacy_page.dart';
import 'package:rectora/ui/screens/terms_page.dart';
import 'package:rectora/ui/widgets/dialogs.dart';
import 'package:rectora/ui/widgets/mark.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final controller = RectoraScope.of(context);
    final message = controller.accountMessage;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
          children: [
            const Center(child: RectoraMark(size: 84)),
            const SizedBox(height: 22),
            Text(
              'RECTORA',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              'Cover rectangles, trace a path, fill regions, and join matching letters.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: palette.muted, height: 1.35),
            ),
            const SizedBox(height: 36),
            if (message != null && message.isNotEmpty) ...[
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: controller.accountMessageIsError
                      ? palette.rose
                      : palette.ink,
                ),
              ),
              const SizedBox(height: 14),
            ],
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: palette.pine,
                foregroundColor: const Color(0xFF10210E),
                shape: const StadiumBorder(),
              ),
              onPressed: controller.authBusy ? null : controller.enterApp,
              child: const Text('Play as Guest'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                foregroundColor: palette.pine,
                side: BorderSide(color: palette.pine, width: 1.4),
                shape: const StadiumBorder(),
              ),
              onPressed: controller.authBusy
                  ? null
                  : () async {
                      await controller.signInWithGoogle();
                      if (!controller.save.isGuest) {
                        await controller.enterApp();
                      }
                    },
              child: controller.authBusy
                  ? const Text('Signing in')
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GoogleMark(),
                          SizedBox(width: 10),
                          Text('Continue with Google'),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              'Guest progress is stored on this device. Clearing app data or uninstalling may erase it. Link Google later from Settings to sync.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.muted, height: 1.35),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => pushSoft(context, const PrivacyPage()),
              child: Text('Privacy', style: TextStyle(color: palette.pine)),
            ),
            TextButton(
              onPressed: () => pushSoft(context, const TermsPage()),
              child: Text('Terms', style: TextStyle(color: palette.pine)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF1A73E8),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class OfflinePage extends StatelessWidget {
  const OfflinePage({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Internet is required',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Connect to the internet, then try again. Rectora stays here until the connection is back.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: palette.pine,
                  foregroundColor: const Color(0xFF10210E),
                  shape: const StadiumBorder(),
                ),
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
