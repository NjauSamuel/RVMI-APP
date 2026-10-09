import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/network/endpoints.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Endpoints.resolve();

  try {
    // Firebase config (google-services.json / GoogleService-Info.plist) is
    // provisioned per-environment; if it's missing (e.g. a dev checkout
    // before FlutterFire is configured) push just silently stays off
    // instead of crashing the whole app on launch.
    await Firebase.initializeApp();
  } catch (_) {
    // No Firebase config yet - continue without push notifications.
  }

  runApp(const ProviderScope(child: RvmiMediaApp()));
}
