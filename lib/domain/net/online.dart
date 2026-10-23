import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Widget tests do not have a reliable network, so they skip this gate.
bool get onlineCheckEnabled {
  final binding = WidgetsBinding.instance.runtimeType.toString();
  return !binding.contains('Test');
}

Future<bool> deviceIsOnline() async {
  try {
    final result = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 4));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  } catch (_) {
    return false;
  }
}
