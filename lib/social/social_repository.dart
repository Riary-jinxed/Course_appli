import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/run.dart';

/// Projet Supabase de l'appli. Les valeurs sont intégrées à l'APK : tout le
/// monde se connecte au même projet, sans configuration.
///
/// La clé "publishable" est publique par nature (elle est embarquée dans
/// l'appli) : ce sont les règles RLS de supabase/schema.sql qui protègent les
/// données. Ne jamais mettre ici la clé "secret" / "service_role".
///
/// On peut viser un autre projet (ex. de test) avec
/// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sugakqqbwaffqqplczvs.supabase.co',
  );
  static const key = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_3mJgucqpj77vucP0btKrrQ_3QC2xxEC',
  );
  static bool get enabled => url.isNotEmpty && key.isNotEmpty;
}

class PublicProfile {
  final String id;
  final String username;
  final String displayName;
  const PublicProfile(this.id, this.username, this.displayName);

  String get label => displayName.isEmpty ? username : displayName;

  factory PublicProfile.fromMap(Map<String, dynamic> m) =>
      PublicProfile(m['id'] as String, m['username'] as String, m['display_name'] as String? ?? '');
}

class Friendship {
  final PublicProfile other;
  final bool accepted;

  /// true si c'est moi qui ai envoyé la demande.
  final bool outgoing;
  const Friendship(this.other, this.accepted, this.outgoing);
}

class SharedRun {
  final String userId;
  final String? userLabel;
  final DateTime startedAt;
  final double distanceM;
  final int movingS;
  final double elevGainM;
  final double calories;

  const SharedRun({
    required this.userId,
    this.userLabel,
    required this.startedAt,
    required this.distanceM,
    required this.movingS,
    required this.elevGainM,
    required this.calories,
  });

  double get avgSpeedMps => movingS == 0 ? 0 : distanceM / movingS;

  factory SharedRun.fromMap(Map<String, dynamic> m) {
    final p = m['profiles'] as Map<String, dynamic>?;
    return SharedRun(
      userId: m['user_id'] as String,
      userLabel: p == null ? null : PublicProfile.fromMap(p).label,
      startedAt: DateTime.parse(m['started_at'] as String).toLocal(),
      distanceM: (m['distance_m'] as num).toDouble(),
      movingS: m['moving_s'] as int,
      elevGainM: (m['elev_gain_m'] as num).toDouble(),
      calories: (m['calories'] as num).toDouble(),
    );
  }
}

class RunGroup {
  final String id;
  final String name;
  final String owner;
  final String inviteCode;
  const RunGroup(this.id, this.name, this.owner, this.inviteCode);

  factory RunGroup.fromMap(Map<String, dynamic> m) => RunGroup(
      m['id'] as String, m['name'] as String, m['owner'] as String, m['invite_code'] as String);
}

class LeaderboardEntry {
  final String userId;
  final String label;
  final int runs;
  final double distanceM;
  final int movingS;
  final double elevGainM;
  const LeaderboardEntry(this.userId, this.label, this.runs, this.distanceM, this.movingS, this.elevGainM);

  double get avgSpeedMps => movingS == 0 ? 0 : distanceM / movingS;
}

/// Totaux d'une personne sur une période, pour les comparaisons.
class StatsSummary {
  final int runs;
  final double distanceM;
  final int movingS;
  final double elevGainM;
  final double longestM;
  const StatsSummary(this.runs, this.distanceM, this.movingS, this.elevGainM, this.longestM);

  double get avgSpeedMps => movingS == 0 ? 0 : distanceM / movingS;

  factory StatsSummary.of(Iterable<SharedRun> runs) => StatsSummary(
        runs.length,
        runs.fold(0, (s, r) => s + r.distanceM),
        runs.fold(0, (s, r) => s + r.movingS),
        runs.fold(0, (s, r) => s + r.elevGainM),
        runs.fold(0, (s, r) => r.distanceM > s ? r.distanceM : s),
      );
}

/// Accès à la partie sociale (comptes, amis, groupes, partage) via Supabase.
class SocialRepository {
  SupabaseClient get _db => Supabase.instance.client;

  static Future<void> init() async {
    if (!SupabaseConfig.enabled) return;
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.key);
  }

  String? get userId => SupabaseConfig.enabled ? _db.auth.currentUser?.id : null;
  Stream<AuthState> get authChanges => _db.auth.onAuthStateChange;

  // --- Compte -------------------------------------------------------------

  Future<void> signUp(String email, String password) =>
      _db.auth.signUp(email: email.trim(), password: password);

  Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email.trim(), password: password);

  Future<void> signOut() => _db.auth.signOut();

  Future<PublicProfile?> myProfile() async {
    final id = userId;
    if (id == null) return null;
    final row = await _db.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : PublicProfile.fromMap(row);
  }

  /// Renvoie un message d'erreur, ou null si OK.
  Future<String?> saveProfile(String username, String displayName) async {
    final u = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(u)) {
      return '3 à 20 caractères : lettres minuscules, chiffres ou _';
    }
    try {
      await _db.from('profiles').upsert({'id': userId, 'username': u, 'display_name': displayName.trim()});
      return null;
    } on PostgrestException catch (e) {
      return e.code == '23505' ? 'Ce pseudo est déjà pris' : e.message;
    }
  }

  // --- Amis ---------------------------------------------------------------

  Future<List<PublicProfile>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    final rows = await _db
        .from('profiles')
        .select()
        .ilike('username', '${q.replaceAll('%', '').replaceAll('_', r'\_')}%')
        .neq('id', userId!)
        .limit(20);
    return rows.map(PublicProfile.fromMap).toList();
  }

  Future<List<Friendship>> friendships() async {
    final me = userId!;
    final rows = await _db.from('friendships').select(
        'requester, addressee, status, '
        'req:profiles!friendships_requester_fkey(id, username, display_name), '
        'addr:profiles!friendships_addressee_fkey(id, username, display_name)');
    return rows.map((r) {
      final outgoing = r['requester'] == me;
      final other = PublicProfile.fromMap((outgoing ? r['addr'] : r['req']) as Map<String, dynamic>);
      return Friendship(other, r['status'] == 'accepted', outgoing);
    }).toList();
  }

  Future<void> sendRequest(String otherId) async {
    final me = userId!;
    // Si l'autre m'a déjà invité, on accepte directement.
    final reverse = await _db
        .from('friendships')
        .select('status')
        .eq('requester', otherId)
        .eq('addressee', me)
        .maybeSingle();
    if (reverse != null) return accept(otherId);
    await _db.from('friendships').upsert({'requester': me, 'addressee': otherId}, ignoreDuplicates: true);
  }

  Future<void> accept(String requesterId) => _db
      .from('friendships')
      .update({'status': 'accepted'})
      .eq('requester', requesterId)
      .eq('addressee', userId!);

  Future<void> removeFriend(String otherId) {
    final me = userId!;
    return _db.from('friendships').delete().or(
        'and(requester.eq.$me,addressee.eq.$otherId),and(requester.eq.$otherId,addressee.eq.$me)');
  }

  // --- Partage de courses -------------------------------------------------

  Future<void> shareRun(Run run) => _db.from('shared_runs').upsert({
        'user_id': userId,
        'local_id': run.id,
        'started_at': run.startedAt.toUtc().toIso8601String(),
        'distance_m': run.distanceM,
        'moving_s': run.movingTime.inSeconds,
        'elev_gain_m': run.elevationGainM,
        'calories': run.calories,
      }, onConflict: 'user_id,local_id');

  Future<void> unshareRun(int localId) =>
      _db.from('shared_runs').delete().eq('user_id', userId!).eq('local_id', localId);

  Future<bool> isShared(int localId) async {
    if (userId == null) return false;
    final row = await _db
        .from('shared_runs')
        .select('id')
        .eq('user_id', userId!)
        .eq('local_id', localId)
        .maybeSingle();
    return row != null;
  }

  /// Dernières courses de mes amis et des membres de mes groupes.
  Future<List<SharedRun>> feed() async {
    final rows = await _db
        .from('shared_runs')
        .select('*, profiles(id, username, display_name)')
        .neq('user_id', userId!)
        .order('started_at', ascending: false)
        .limit(50);
    return rows.map(SharedRun.fromMap).toList();
  }

  Future<List<SharedRun>> runsOf(String uid, DateTime since) async {
    final rows = await _db
        .from('shared_runs')
        .select()
        .eq('user_id', uid)
        .gte('started_at', since.toUtc().toIso8601String());
    return rows.map(SharedRun.fromMap).toList();
  }

  // --- Groupes ------------------------------------------------------------

  Future<List<RunGroup>> myGroups() async {
    final rows = await _db.from('groups').select().order('created_at');
    return rows.map(RunGroup.fromMap).toList();
  }

  Future<RunGroup> createGroup(String name) async {
    final row = await _db.from('groups').insert({'name': name.trim(), 'owner': userId}).select().single();
    return RunGroup.fromMap(row);
  }

  /// Renvoie un message d'erreur, ou null si OK.
  Future<String?> joinGroup(String code) async {
    try {
      await _db.rpc('join_group', params: {'code': code});
      return null;
    } on PostgrestException catch (e) {
      return e.message.contains('Code invalide') ? 'Code invalide' : e.message;
    }
  }

  Future<void> leaveGroup(String groupId) =>
      _db.from('group_members').delete().eq('group_id', groupId).eq('user_id', userId!);

  Future<void> deleteGroup(String groupId) => _db.from('groups').delete().eq('id', groupId);

  Future<List<LeaderboardEntry>> leaderboard(String groupId, DateTime since) async {
    final rows = await _db.rpc('group_leaderboard',
        params: {'g': groupId, 'since': since.toUtc().toIso8601String()}) as List<dynamic>;
    return rows.cast<Map<String, dynamic>>().map((r) {
      final display = r['display_name'] as String? ?? '';
      return LeaderboardEntry(
        r['user_id'] as String,
        display.isEmpty ? r['username'] as String : display,
        (r['runs'] as num).toInt(),
        (r['distance_m'] as num).toDouble(),
        (r['moving_s'] as num).toInt(),
        (r['elev_gain_m'] as num).toDouble(),
      );
    }).toList();
  }
}
