import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/study_plan_store.dart';
import 'data/study_plan_storage.dart';
import 'data/settings_store.dart';
import 'pages/study_home_page.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load(
    storage: SharedPreferencesSettingsStorage(),
  );
  final store = await StudyPlanStore.load(
    storage: SharedPreferencesPlanStorage(),
    settings: settings,
  );
  runApp(MyApp(store: store, settings: settings));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.store, this.settings});

  final StudyPlanStore? store;
  final SettingsStore? settings;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final StudyPlanStore _store;
  late final SettingsStore _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings ?? SettingsStore();
    _store = widget.store ?? StudyPlanStore(settings: _settings);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _store.refreshForToday();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _store.flush();
      _settings.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        locale: Locale(_settings.settings.localeCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        themeMode: _settings.settings.themeMode,
        theme: AppTheme.forBrightness(Brightness.light),
        darkTheme: AppTheme.forBrightness(Brightness.dark),
        home: StudyHomePage(store: _store, settings: _settings),
      ),
    );
  }
}
