import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/study_plan_store.dart';
import 'data/study_plan_storage.dart';
import 'data/settings_store.dart';
import 'pages/study_home_page.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'data/study_snapshot.dart';
import 'models/app_settings.dart';
import 'pages/backup_page.dart';
import 'services/backup_file_access.dart';
import 'services/study_backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

/// No migration, reconciliation or default writes occur before both reads validate.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    this.planStorage,
    this.settingsStorage,
    this.files,
    this.now,
    this.cancelNotifications,
  });
  final StudyPlanStorage? planStorage;
  final AppSettingsStorage? settingsStorage;
  final BackupFileAccess? files;
  final DateTime Function()? now;
  final Future<void> Function()? cancelNotifications;
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final _planStorage =
      widget.planStorage ?? SharedPreferencesPlanStorage();
  late final _settingsStorage =
      widget.settingsStorage ?? SharedPreferencesSettingsStorage();
  late final _backups = StudyBackupService(
    planStorage: _planStorage,
    settingsStorage: _settingsStorage,
    files: widget.files,
    now: widget.now,
    cancelNotifications: widget.cancelNotifications,
  );
  bool _loading = true;
  bool _working = false;
  bool _unsupportedVersion = false;
  StudyPlanStore? _store;
  SettingsStore? _settings;
  AppSettings? _knownSettings;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_working) return;
    _working = true;
    setState(() {
      _loading = true;
      _unsupportedVersion = false;
    });
    SettingsStore? settings;
    StudyPlanStore? store;
    try {
      await _backups.recoverPending();
      final raw = await Future.wait([
        _planStorage.read(),
        _settingsStorage.read(),
      ]);
      final values = decodeSettingsSnapshot(raw[1]);
      _knownSettings = values;
      final snapshot = await compute(StudyPlanSnapshot.decode, raw[0]);
      settings = SettingsStore(storage: _settingsStorage, settings: values);
      store = StudyPlanStore.fromSnapshot(
        snapshot,
        storage: _planStorage,
        settings: settings,
        now: widget.now,
      );
      if (raw[1] != null && raw[1] != jsonEncode(values.toJson())) {
        settings.update(values);
      }
      if (!mounted) {
        store.dispose();
        settings.dispose();
        return;
      }
      setState(() {
        _store = store;
        _settings = settings;
        _loading = false;
      });
    } catch (error) {
      store?.dispose();
      settings?.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _unsupportedVersion = error is SnapshotVersionException;
        });
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _restore(BuildContext context) async {
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BackupPage(
          service: _backups,
          initialAction: BackupAction.importData,
          closeAfterRestore: true,
        ),
      ),
    );
    if (restored == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_store != null) return MyApp(store: _store, settings: _settings);
    final system =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(
        _knownSettings?.localeCode ?? (system == 'en' ? 'en' : 'zh'),
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: AppTheme.forBrightness(Brightness.light),
      darkTheme: AppTheme.forBrightness(Brightness.dark),
      themeMode: _knownSettings?.themeMode ?? ThemeMode.system,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(title: Text(l10n.appTitle)),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loading)
                          const CircularProgressIndicator()
                        else
                          Icon(
                            Icons.storage_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        const SizedBox(height: 20),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _loading
                                ? l10n.loadingLocalData
                                : l10n.loadingDataFailed,
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (!_loading) ...[
                          const SizedBox(height: 12),
                          Text(
                            _unsupportedVersion
                                ? l10n.localVersionUnsupported
                                : l10n.loadingDataFailedHint,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const ValueKey('retry_loading'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: _load,
                              child: Text(l10n.retryLoading),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              key: const ValueKey('startup_restore_backup'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => _restore(context),
                              child: Text(l10n.importBackup),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
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
