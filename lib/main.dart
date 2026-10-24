import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/shell.dart';
import 'app/tabs.dart';
import 'app/theme.dart';
import 'data/catalog.dart';
import 'firebase_options.dart';
import 'logic/reminders.dart';
import 'state/cloud.dart';
import 'state/log_store.dart';
import 'state/prefs_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Light status bar text over the dark floor.
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;
  // Not awaited: the app opens straight away, and the stores wait for the user to save.
  final user = signIn(FirebaseAuth.instance, db);
  final results = await Future.wait([Catalog.load(db: db), SharedPreferences.getInstance()]);
  final prefs = results[1] as SharedPreferences;
  final prefsStore = PrefsStore(prefs, user);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => prefsStore),
        ChangeNotifierProvider(create: (_) => LogStore(user)),
        ChangeNotifierProvider(create: (_) => TabNav()),
      ],
      child: const VitalizeApp(),
    ),
  );
  // Training reminders follow the phone's time zone: once the first frame is up, schedule
  // them again in the current one (no permission dialog at start-up).
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(Reminders.instance.refreshAtLaunch(prefsStore.settings.reminder)),
  );
}

class VitalizeApp extends StatelessWidget {
  const VitalizeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vitalize',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    // Every screen, pushed ones included, gets the app's text style and a Material ancestor.
    builder: (context, child) => Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(style: VT.body, child: child!),
    ),
    home: const Shell(),
  );
}
