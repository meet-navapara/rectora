import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/home/home_art.dart';
import 'package:rectora/ui/home/home_motion.dart';

class HomeAtmosphere extends StatefulWidget {
  const HomeAtmosphere({super.key});

  @override
  State<HomeAtmosphere> createState() => _HomeAtmosphereState();
}

class _HomeAtmosphereState extends State<HomeAtmosphere>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? motion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    motion?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = motion;
    if (controller == null) return;
    if (state == AppLifecycleState.resumed) {
      if (homeMotionEnabled(context)) controller.repeat();
    } else {
      controller.stop();
    }
  }

  void _sync() {
    final allow =
        homeMotionEnabled(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!allow) {
      motion?.stop();
      return;
    }
    final controller = motion ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (!controller.isAnimating) controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final controller = motion;
    if (controller == null) {
      return CustomPaint(
        painter: HomeAtmospherePainter(palette: palette, shift: 0),
        child: const SizedBox.expand(),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: HomeAtmospherePainter(
            palette: palette,
            shift: controller.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class HomePressable extends StatefulWidget {
  const HomePressable({
    super.key,
    required this.onTap,
    required this.label,
    required this.child,
  });

  final VoidCallback? onTap;
  final String label;
  final Widget child;

  @override
  State<HomePressable> createState() => _HomePressableState();
}

class _HomePressableState extends State<HomePressable> {
  var held = false;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final reduce = !homeMotionEnabled(context);
    return Semantics(
      button: widget.onTap != null,
      label: widget.label,
      child: AnimatedScale(
        scale: held && !reduce ? 0.985 : 1,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 120),
        curve: RectoraTokens.ease,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RectoraTokens.cardRadius),
            boxShadow: [
              BoxShadow(
                color: palette.grid.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: palette.surface,
            borderRadius: BorderRadius.circular(RectoraTokens.cardRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (value) => setState(() => held = value),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class HomeProgress extends StatelessWidget {
  const HomeProgress({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final target = value.clamp(0.0, 1.0);
    final reduce = !homeMotionEnabled(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? target : 0, end: target),
      duration: reduce ? Duration.zero : RectoraTokens.reveal,
      curve: RectoraTokens.ease,
      builder: (context, shown, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: palette.line.withValues(alpha: 0.45)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: shown,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [palette.copper, palette.pine],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
