import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/ads.dart';
import 'app/config/app_config.dart';
import 'app/deep_link.dart';
import 'app/navigation.dart';
import 'app/providers.dart';
import 'app/theme/app_theme.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0B0F14),
  ));
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final link = await readIncomingLink();
  await initializeDateFormatting();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: CinevaApp(initialLink: link),
    ),
  );
}

class CinevaApp extends ConsumerStatefulWidget {
  final CinevaLink? initialLink;
  const CinevaApp({super.key, this.initialLink});

  @override
  ConsumerState<CinevaApp> createState() => _CinevaAppState();
}

class _CinevaAppState extends ConsumerState<CinevaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _linkHandled = true;

  @override
  void initState() {
    super.initState();
    _linkHandled = widget.initialLink == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Ads.bootstrap();
      ref.read(bootstrapProvider);
    });
  }

  void _routeIncomingLink() {
    if (_linkHandled) return;
    _linkHandled = true;
    final screen = DeepLinkRouter.widgetFor(widget.initialLink);
    if (screen != null) {
      _navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);
    final bootstrapped = ref.watch(bootstrapProvider);
    Intl.defaultLocale = settings.languageCode.startsWith('tr') ? 'tr' : 'en';
    final ready = bootstrapped.hasValue && settings.onboardingDone;
    if (ready) WidgetsBinding.instance.addPostFrameCallback((_) => _routeIncomingLink());

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      locale: Locale(settings.languageCode),
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeAnimationDuration: Duration.zero,
      home: bootstrapped.isLoading
          ? const _Splash()
          : (!settings.onboardingDone ? const OnboardingScreen() : const HomeShell()),
      onGenerateRoute: (r) {
        if (r.name == '/deeplink') {
          final route = DeepLinkRouter.routeFor(widget.initialLink);
          if (route != null) return route;
        }
        return MaterialPageRoute(builder: (_) => const HomeShell());
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/icon/logo_512.png',
                width: 84,
                height: 84,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 18),
            Text(AppConfig.appName,
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : AppTheme.darkBg,
                    letterSpacing: -0.4)),
            const SizedBox(height: 22),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
