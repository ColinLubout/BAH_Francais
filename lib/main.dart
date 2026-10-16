import 'dart:async';

import 'package:bah_francais/app/app.dart';
import 'package:bah_francais/app/licences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars on every Android version, as
  // Android 15+ does anyway, so the background runs to the screen's edges.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  registerLicences();
  runApp(const ProviderScope(child: BahApp()));
}
