import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Force Firestore to use long-polling instead of the WebChannel stream.
  // The WebChannel is silently blocked by some browsers/extensions (Brave
  // Shields, ad blockers) and by proxies/corporate networks, which makes
  // every Firestore read hang forever even though plain HTTPS works. Long
  // polling uses ordinary HTTP requests, so reads succeed everywhere. This
  // matters for an emergency app used on unpredictable networks/devices.
  //
  // Persistence is intentionally left at its default (off on web): enabling
  // the IndexedDB cache can stall collection queries in restricted/multi-tab
  // environments, and the app always wants fresh data anyway.
  FirebaseFirestore.instance.settings = const Settings(
    webExperimentalForceLongPolling: true,
  );

  usePathUrlStrategy();
  runApp(const App());
}
