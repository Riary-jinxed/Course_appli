# Course

Application de suivi de course à pied (Flutter, Android d'abord puis iOS).

## Fonctionnalités du MVP

- **Profil** : prénom, poids, taille, sexe, date de naissance, FC max (stocké sur le téléphone)
- **Course en direct** : carte OpenStreetMap avec tracé, temps, distance, allure, vitesse moyenne,
  calories, dénivelé positif/négatif, podomètre. Le suivi continue écran éteint (service au premier plan).
- **Checkpoints** : marquage pendant la course, avec temps et allure entre chaque checkpoint
- **Annonces vocales** : tous les X km ou X minutes (réglable dans le profil)
- **Historique** : liste des courses, détail avec carte, stats, profil d'altitude et checkpoints

## Calculs

- Distance : haversine entre points GPS, points de précision > 25 m et sauts > 43 km/h ignorés,
  auto-pause sous 0,5 m/s.
- Dénivelé : cumul avec un seuil de 3 m pour filtrer le bruit de l'altitude GPS.
- Calories : équations métaboliques ACSM (marche / course), en fonction du poids, de la vitesse et de la pente.

## Lancer le projet

```bash
flutter pub get
flutter test
flutter run            # téléphone Android branché en mode débogage USB
flutter build apk      # APK dans build/app/outputs/flutter-apk/
```

## Structure

```
lib/
  models/        UserProfile, Run, TrackPoint, Checkpoint
  services/      calculs (geo, calories, run_metrics), stockage SQLite, voix
  controllers/   RunTracker : GPS + podomètre + chrono pendant une course
  screens/       accueil, profil, course en direct, détail d'une course
  widgets/       carte, tuiles de stats
```

## Feuille de route

1. **MVP** (ce dépôt) : profil, GPS, stats, checkpoints, historique, annonces vocales
2. **Social et entraînement** : comptes, amis, groupes, comparaison de stats, objectifs d'événement,
   programmes de préparation
3. **Connecté** : commandes vocales, Spotify, montres (Health Connect, Wear OS, Garmin)
4. **Assistante IA locale** : coach à règles puis petit modèle sur l'appareil
