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
import 'social/social_repository.dart';
import 'training/plan_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final profiles = ProfileRepository();
  final profile = await profiles.load();
  final coachSettings = await profiles.loadCoachSettings();
  final coach = VoiceCoach(mode: coachSettings.$1, interval: coachSettings.$2);
  await coach.init();
  final runs = RunRepository();
  await SocialRepository.init();

  runApp(MultiProvider(
    providers: [
      Provider.value(value: profiles),
      Provider.value(value: runs),
      Provider.value(value: coach),
      Provider(create: (_) => PlanRepository(runs)),
      Provider(create: (_) => SocialRepository()),
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
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: hasProfile ? const RootScreen() : const ProfileScreen(firstLaunch: true),
    );
  }
}
