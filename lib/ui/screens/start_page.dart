import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/home/home_art.dart';
import 'package:rectora/ui/home/home_cards.dart';
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
    final theme = Theme.of(context);
    final message = controller.accountMessage;
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          const HomeAtmosphere(),
          // Keeps the background's dots and lines from showing behind buttons.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.background.withValues(alpha: 0),
                    palette.background,
                  ],
                  stops: const [0.5, 0.68],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // On a short phone the buttons matter more than the preview.
                final roomForModes = constraints.maxHeight >= 640;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: RectoraMark(size: 76)),
                              const SizedBox(height: 18),
                              Text(
                                'RECTORA',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Four kinds of puzzle.\nOne answer to every board.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: palette.muted,
                                  height: 1.4,
                                ),
                              ),
                              if (roomForModes) ...[
                                const SizedBox(height: 28),
                                const _ModeGrid(),
                              ],
                              const SizedBox(height: 32),
                              if (message != null && message.isNotEmpty) ...[
                                Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
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
                                  backgroundColor: palette.copper,
                                  foregroundColor: palette.copperInk,
                                  shape: const StadiumBorder(),
                                  textStyle: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                onPressed: controller.authBusy
                                    ? null
                                    : controller.enterApp,
                                child: const Text('Play as Guest'),
                              ),
                              const SizedBox(height: 12),
                              _GoogleButton(
                                busy: controller.authBusy,
                                onPressed: () async {
                                  await controller.signInWithGoogle();
                                  if (!controller.save.isGuest) {
                                    await controller.enterApp();
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Guest progress stays on this phone. Sign in with Google to keep it safe across devices.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: palette.muted,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _LegalLink(
                                    label: 'Privacy',
                                    page: const PrivacyPage(),
                                  ),
                                  Text(
                                    '·',
                                    style: TextStyle(color: palette.muted),
                                  ),
                                  _LegalLink(
                                    label: 'Terms',
                                    page: const TermsPage(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A quick look at the four modes, using the same art as the home screen.
class _ModeGrid extends StatelessWidget {
  const _ModeGrid();

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _ModeTile('Parcels', ParcelArtPainter(palette))),
            const SizedBox(width: 10),
            Expanded(child: _ModeTile('Trace', TraceArtPainter(palette))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _ModeTile('Inks', InkArtPainter(palette))),
            const SizedBox(width: 10),
            Expanded(child: _ModeTile('Threads', ThreadArtPainter(palette))),
          ],
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile(this.title, this.art);

  final String title;
  final CustomPainter art;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: palette.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 72, child: CustomPaint(painter: art)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Follows Google's sign-in button guidance: a white button with the
/// standard four-color mark.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F1F1F);
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        disabledBackgroundColor: Colors.white,
        disabledForegroundColor: ink,
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFF747775))),
        textStyle: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      onPressed: busy ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
            )
          else
            CustomPaint(
              size: const Size.square(20),
              painter: _GoogleMarkPainter(),
            ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              busy ? 'Signing in…' : 'Continue with Google',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);
    final red = Path()
      ..moveTo(24, 9.5)
      ..relativeCubicTo(3.54, 0, 6.71, 1.22, 9.21, 3.6)
      ..relativeLineTo(6.85, -6.85)
      ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
      ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
      ..relativeLineTo(7.98, 6.19)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
      ..close();
    final blue = Path()
      ..moveTo(46.98, 24.55)
      ..relativeCubicTo(0, -1.57, -0.15, -3.09, -0.38, -4.55)
      ..lineTo(24, 20)
      ..relativeLineTo(0, 9.02)
      ..relativeLineTo(12.94, 0)
      ..relativeCubicTo(-0.58, 2.96, -2.26, 5.48, -4.78, 7.18)
      ..relativeLineTo(7.73, 6)
      ..relativeCubicTo(4.51, -4.18, 7.09, -10.36, 7.09, -17.65)
      ..close();
    final yellow = Path()
      ..moveTo(10.53, 28.59)
      ..relativeCubicTo(-0.48, -1.45, -0.76, -2.99, -0.76, -4.59)
      ..relativeCubicTo(0, -1.6, 0.27, -3.14, 0.76, -4.59)
      ..relativeLineTo(-7.98, -6.19)
      ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
      ..relativeCubicTo(0, 3.88, 0.92, 7.54, 2.56, 10.78)
      ..relativeLineTo(7.97, -6.19)
      ..close();
    final green = Path()
      ..moveTo(24, 48)
      ..relativeCubicTo(6.48, 0, 11.93, -2.13, 15.89, -5.81)
      ..relativeLineTo(-7.73, -6)
      ..relativeCubicTo(-2.15, 1.45, -4.92, 2.3, -7.76, 2.3)
      ..relativeCubicTo(-6.26, 0, -11.57, -4.22, -13.46, -9.91)
      ..relativeLineTo(-7.98, 6.19)
      ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
      ..close();
    canvas.drawPath(red, Paint()..color = const Color(0xFFEA4335));
    canvas.drawPath(blue, Paint()..color = const Color(0xFF4285F4));
    canvas.drawPath(yellow, Paint()..color = const Color(0xFFFBBC05));
    canvas.drawPath(green, Paint()..color = const Color(0xFF34A853));
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.page});

  final String label;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return TextButton(
      onPressed: () => pushSoft(context, page),
      child: Text(label, style: TextStyle(color: palette.muted)),
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
