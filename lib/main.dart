import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/screens/camera_screen.dart';
import 'localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '/commons/widgets.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb == false) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]).then((_) {
      runApp(ProviderScope(child: MyApp()));
    });
  } else {
    runApp(ProviderScope(child: MyApp()));
  }
}

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: []);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Keep Me',
      theme: myDarkTheme,
      home: CameraScreen(),
      localizationsDelegates: [
        const SampleLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', ''),
        const Locale('ja', ''),
      ],
    );
  }
}
