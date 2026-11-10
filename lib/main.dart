import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'controllers/run_tracker.dart';
import 'models/user_profile.dart';
import 'screens/root_screen.dart';
import 'screens/profile_screen.dart';
import 'services/profile_repository.dart';
import 'services/run_repository.dart';
import 'services/voice_coach.dart';
import 'music/spotify_controller.dart';
import 'records/records_repository.dart';
import 'safety/safety.dart';
import 'shoes/shoes.dart';
import 'notifications/notification_service.dart';
import 'nutrition/nutrition_repository.dart';
import 'social/backup_service.dart';
import 'social/social_repository.dart';
import 'training/plan_repository.dart';
import 'map/map_style.dart';
import 'theme/app_theme.dart';
import 'update/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await MapStyleSetting.load();
  final profiles = ProfileRepository();
  final profile = await profiles.load();
  final coachSettings = await profiles.loadCoachSettings();
  final coach = VoiceCoach(mode: coachSettings.$1, interval: coachSettings.$2);
  await coach.init();
  final runs = RunRepository();
  await SocialRepository.init();
  final social = SocialRepository();
  final backup = BackupService(runs, social)..start();
  final plans = PlanRepository(runs);
  final notifications = NotificationService(plans);
  await notifications.init();
  // Reprogramme les rappels (séances à venir) à chaque lancement.
  notifications.reschedule();

  runApp(MultiProvider(
    providers: [
      Provider.value(value: profiles),
      Provider.value(value: runs),
      Provider.value(value: coach),
      Provider.value(value: plans),
      Provider.value(value: notifications),
      Provider(create: (_) => NutritionRepository(runs)),
      ChangeNotifierProvider(create: (_) => SpotifyController()),
      Provider(create: (_) => RecordsRepository(runs)),
      Provider(create: (_) => ShoeRepository(runs)),
      Provider(create: (_) => LiveShare(social)),
      Provider.value(value: social),
      ChangeNotifierProvider.value(value: backup),
      ChangeNotifierProvider(create: (_) => UpdateService()..start(), lazy: false),
      ChangeNotifierProvider(create: (_) => ProfileState(profiles, profile)),
      ChangeNotifierProvider(create: (_) => RunTracker(repository: runs, coach: coach)),
    ],
    child: const CourseApp(),
  ));
}

/// Profil courant, partagé dans toute l'appli.
class ProfileState extends ChangeNotifier {
  final ProfileRepository _repo;
  UserProfile? profile;
  ProfileState(this._repo, this.profile);

  Future<void> update(UserProfile p) async {
    profile = p;
    await _repo.save(p);
    notifyListeners();
  }
}

class CourseApp extends StatelessWidget {
  const CourseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final hasProfile = context.select<ProfileState, bool>((s) => s.profile != null);
    return MaterialApp(
      title: 'Course',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: hasProfile ? const RootScreen() : const ProfileScreen(firstLaunch: true),
    );
  }
}
