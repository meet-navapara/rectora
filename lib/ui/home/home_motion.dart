import 'package:flutter/widgets.dart';

/// Ambient motion stays off during widget tests so [WidgetTester.pumpAndSettle]
/// can finish, and off when the player or the system asks for reduced motion.
bool homeMotionEnabled(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return false;
  final binding = WidgetsBinding.instance.runtimeType.toString();
  return !binding.contains('Test');
}
