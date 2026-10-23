import 'package:flutter/material.dart';
import 'package:rectora/ui/controller.dart';

class RectoraScope extends InheritedNotifier<RectoraController> {
  const RectoraScope({
    super.key,
    required RectoraController controller,
    required super.child,
  }) : super(notifier: controller);

  static RectoraController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RectoraScope>();
    assert(scope != null, 'RectoraScope is missing above this widget.');
    return scope!.notifier!;
  }

  static RectoraController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RectoraScope>();
    assert(scope != null, 'RectoraScope is missing above this widget.');
    return scope!.notifier!;
  }
}
