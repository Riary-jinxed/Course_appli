# Course

Application de suivi de course à pied (Flutter, Android d'abord puis iOS).

## Fonctionnalités du MVP

- **Profil** : prénom, poids, taille, sexe, date de naissance, FC max (stocké sur le téléphone)
- **Course en direct** : carte OpenStreetMap avec tracé, temps, distance, allure, vitesse moyenne,
  calories, dénivelé positif/négatif, podomètre. Le suivi continue écran éteint (service au premier plan).
- **Checkpoints** : marquage pendant la course, avec temps et allure entre chaque checkpoint
- **Annonces vocales** : tous les X km ou X minutes (réglable dans le profil)
- **Historique** : liste des courses, détail avec carte, stats, profil d'altitude et checkpoints

## Phase 2 : entraînement et social

- **Objectifs d'événement** : nom, distance (5 km, 10 km, semi, marathon ou libre), date, temps visé,
  nombre de séances par semaine.
- **Programme de préparation** généré automatiquement : volume qui part de ton niveau des 4 dernières
  semaines, +10 % max par semaine, une semaine allégée sur quatre, fractionné et seuil après 2 semaines
  de base, affûtage sur les 2 dernières semaines. Allures cibles calculées depuis le temps visé.
- **Suivi des séances** : une course enregistrée le jour prévu (ou à ±1 jour) valide la séance ;
  validation manuelle possible.
- **Social** (Supabase) : compte e-mail, pseudo, amis (demande / acceptation), groupes avec code
  d'invitation, partage du résumé d'une course (le tracé GPS reste sur le téléphone), fil des courses
  des amis, classement de groupe (semaine / mois / année), comparaison « moi vs un ami ».

### Supabase (partie sociale)

L'appli est connectée au projet Supabase `sugakqqbwaffqqplczvs` : l'URL et la clé publique sont dans
`lib/social/social_repository.dart`. Un simple `flutter build apk` donne donc un APK prêt à l'emploi
pour tout le monde. La clé publique peut être partagée sans risque ; la sécurité repose sur les règles
RLS de `supabase/schema.sql`. Ne jamais mettre la clé « secret » / « service_role » dans l'appli.

Mise en place d'un nouveau projet : lancer `supabase/schema.sql` dans le *SQL Editor*, puis remplacer
l'URL et la clé, ou les passer avec `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_KEY=…`.

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
  training/      objectifs, générateur de programme, écrans entraînement
  social/        Supabase : comptes, amis, groupes, partage, classements
  services/      calculs (geo, calories, run_metrics), stockage SQLite, voix
  controllers/   RunTracker : GPS + podomètre + chrono pendant une course
  screens/       accueil, profil, course en direct, détail d'une course
  widgets/       carte, tuiles de stats
```

## Feuille de route

1. **MVP** ✓ : profil, GPS, stats, checkpoints, historique, annonces vocales
2. **Social et entraînement** ✓ : comptes, amis, groupes, comparaison de stats, objectifs d'événement,
   programmes de préparation
3. **Connecté** : commandes vocales, Spotify, montres (Health Connect, Wear OS, Garmin)
4. **Assistante IA locale** : coach à règles puis petit modèle sur l'appareil
