import 'package:flutter/material.dart';

import '../nutrition/nutrition_screen.dart';
import '../social/social_screen.dart';
import '../training/training_screen.dart';
import 'home_screen.dart';

/// Navigation principale : Courses, Entraînement, Social.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;
  final _training = GlobalKey<TrainingScreenState>();
  final _nutrition = GlobalKey<NutritionScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          TrainingScreen(key: _training),
          NutritionScreen(key: _nutrition),
          const SocialScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // Une course peut avoir validé une séance : on rafraîchit.
          if (i == 1) _training.currentState?.reload();
          if (i == 2) _nutrition.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_run), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Entraînement'),
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Nutrition'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Social'),
        ],
      ),
    );
  }
}
