import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';

class DialogChoice {
  const DialogChoice({
    required this.label,
    required this.value,
    this.primary = false,
  });

  final String label;
  final Object? value;
  final bool primary;
}

Future<T?> showRectoraDialog<T>({
  required BuildContext context,
  required String title,
  required String body,
  required List<DialogChoice> choices,
  bool barrierDismissible = true,
}) {
  final palette = RectoraTheme.of(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) {
      return Dialog(
        backgroundColor: palette.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(body, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 18),
                for (final choice in choices) ...[
                  _DialogButton(
                    choice: choice,
                    onPressed: () => Navigator.pop(context, choice.value as T),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.choice, required this.onPressed});

  final DialogChoice choice;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final child = Text(choice.label);
    if (choice.primary) {
      return FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: palette.copper,
          foregroundColor: palette.copperInk,
        ),
        onPressed: onPressed,
        child: child,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.line),
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}

Future<T?> pushSoft<T>(BuildContext context, Widget page) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      transitionDuration: reduce
          ? Duration.zero
          : const Duration(milliseconds: 280),
      reverseTransitionDuration: reduce
          ? Duration.zero
          : const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondary) => page,
      transitionsBuilder: (context, animation, secondary, child) {
        if (reduce) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
