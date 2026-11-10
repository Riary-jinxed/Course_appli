import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/geo.dart';
import 'compare_screen.dart';
import 'group_detail_screen.dart';
import 'social_repository.dart';

/// Onglet Social : connexion, fil d'actualité, amis, groupes.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  Future<PublicProfile?>? _profile;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.enabled) {
      _load();
      context.read<SocialRepository>().authChanges.listen((_) {
        if (mounted) _load();
      });
    }
  }

  void _load() => setState(() => _profile = context.read<SocialRepository>().myProfile());

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Social')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "La partie sociale n'est pas encore configurée.\n\n"
            'Crée un projet Supabase, lance le script supabase/schema.sql, '
            'puis démarre l\'appli avec --dart-define=SUPABASE_URL=… et '
            '--dart-define=SUPABASE_KEY=… (voir le README).',
          ),
        ),
      );
    }
    final repo = context.read<SocialRepository>();
    if (repo.userId == null) return _AuthScreen(onDone: _load);
    return FutureBuilder<PublicProfile?>(
      future: _profile,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) return _UsernameScreen(onDone: _load);
        return _SocialHome(me: snap.data!);
      },
    );
  }
}

class _AuthScreen extends StatefulWidget {
  final VoidCallback onDone;
  const _AuthScreen({required this.onDone});

  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = context.read<SocialRepository>();
    try {
      if (_signUp) {
        await repo.signUp(_email.text, _password.text);
      } else {
        await repo.signIn(_email.text, _password.text);
      }
      if (repo.userId == null && _signUp) {
        _error = 'Compte créé : confirme ton adresse via le mail reçu, puis connecte-toi.';
        _signUp = false;
      } else {
        widget.onDone();
      }
    } on AuthException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Connexion impossible : $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Social')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Connecte-toi pour ajouter des amis, rejoindre des groupes et comparer vos stats.'),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'E-mail'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_signUp ? 'Créer mon compte' : 'Se connecter'),
          ),
          TextButton(
            onPressed: () => setState(() => _signUp = !_signUp),
            child: Text(_signUp ? "J'ai déjà un compte" : 'Créer un compte'),
          ),
        ],
      ),
    );
  }
}

class _UsernameScreen extends StatefulWidget {
  final VoidCallback onDone;
  const _UsernameScreen({required this.onDone});

  @override
  State<_UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<_UsernameScreen> {
  final _username = TextEditingController();
  final _display = TextEditingController();
  String? _error;

  Future<void> _save() async {
    final err = await context.read<SocialRepository>().saveProfile(_username.text, _display.text);
    if (err == null) {
      widget.onDone();
    } else if (mounted) {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ton pseudo')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Tes amis te trouveront grâce à ton pseudo.'),
          TextField(
            controller: _username,
            decoration: InputDecoration(labelText: 'Pseudo', prefixText: '@', errorText: _error),
          ),
          TextField(controller: _display, decoration: const InputDecoration(labelText: 'Nom affiché (optionnel)')),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Continuer')),
        ],
      ),
    );
  }
}

class _SocialHome extends StatelessWidget {
  final PublicProfile me;
  const _SocialHome({required this.me});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('@${me.username}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Se déconnecter',
              onPressed: () => context.read<SocialRepository>().signOut(),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Fil'), Tab(text: 'Amis'), Tab(text: 'Groupes')]),
        ),
        body: TabBarView(children: [const _FeedTab(), _FriendsTab(me: me), const _GroupsTab()]),
      ),
    );
  }
}

class _FeedTab extends StatefulWidget {
  const _FeedTab();

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  late Future<List<SharedRun>> _feed = context.read<SocialRepository>().feed();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _feed = context.read<SocialRepository>().feed());
        await _feed;
      },
      child: FutureBuilder<List<SharedRun>>(
        future: _feed,
        builder: (context, snap) {
          if (snap.hasError) return ListView(children: [ListTile(title: Text('Erreur : ${snap.error}'))]);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final runs = snap.data!;
          if (runs.isEmpty) {
            return ListView(children: const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Text('Rien pour le moment. Ajoute des amis ou rejoins un groupe : '
                    'leurs courses partagées apparaîtront ici.', textAlign: TextAlign.center),
              ),
            ]);
          }
          return ListView(children: [
            for (final r in runs)
              ListTile(
                leading: CircleAvatar(child: Text((r.userLabel ?? '?').characters.first.toUpperCase())),
                title: Text('${r.userLabel} · ${(r.distanceM / 1000).toStringAsFixed(2)} km'),
                subtitle: Text('${DateFormat('EEE d MMM, HH:mm', 'fr_FR').format(r.startedAt)} · '
                    '${formatDuration(Duration(seconds: r.movingS))} · ${formatPace(r.avgSpeedMps)} /km'
                    '${r.elevGainM >= 1 ? ' · D+ ${r.elevGainM.round()} m' : ''}'),
              ),
          ]);
        },
      ),
    );
  }
}

class _FriendsTab extends StatefulWidget {
  final PublicProfile me;
  const _FriendsTab({required this.me});

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  late Future<List<Friendship>> _friends;
  final _search = TextEditingController();
  List<PublicProfile> _results = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _friends = context.read<SocialRepository>().friendships());

  Future<void> _doSearch(String q) async {
    final r = await context.read<SocialRepository>().searchUsers(q);
    if (mounted) setState(() => _results = r);
  }

  Future<void> _act(Future<void> Function() f, String message) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await f();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<SocialRepository>();
    return FutureBuilder<List<Friendship>>(
      future: _friends,
      builder: (context, snap) {
        final all = snap.data ?? [];
        final incoming = all.where((f) => !f.accepted && !f.outgoing).toList();
        final outgoing = all.where((f) => !f.accepted && f.outgoing).toList();
        final friends = all.where((f) => f.accepted).toList();
        final knownIds = all.map((f) => f.other.id).toSet();
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_search),
                  hintText: 'Chercher un pseudo',
                ),
                onChanged: _doSearch,
              ),
            ),
            for (final p in _results.where((p) => !knownIds.contains(p.id)))
              ListTile(
                title: Text(p.label),
                subtitle: Text('@${p.username}'),
                trailing: IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () => _act(() => repo.sendRequest(p.id), 'Demande envoyée à ${p.label}'),
                ),
              ),
            if (incoming.isNotEmpty) const _Header('Demandes reçues'),
            for (final f in incoming)
              ListTile(
                title: Text(f.other.label),
                subtitle: Text('@${f.other.username}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _act(() => repo.removeFriend(f.other.id), 'Demande refusée'),
                  ),
                  IconButton.filled(
                    icon: const Icon(Icons.check),
                    onPressed: () => _act(() => repo.accept(f.other.id), '${f.other.label} est ton ami·e'),
                  ),
                ]),
              ),
            const _Header('Amis'),
            if (snap.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (friends.isEmpty)
              const ListTile(title: Text('Cherche le pseudo de tes amis pour les ajouter.')),
            for (final f in friends)
              ListTile(
                leading: CircleAvatar(child: Text(f.other.label.characters.first.toUpperCase())),
                title: Text(f.other.label),
                subtitle: Text('@${f.other.username} · touche pour comparer'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CompareScreen(me: widget.me, other: f.other)),
                ),
                trailing: PopupMenuButton<String>(
                  itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Retirer'))],
                  onSelected: (_) => _act(() => repo.removeFriend(f.other.id), 'Ami retiré'),
                ),
              ),
            if (outgoing.isNotEmpty) const _Header('En attente'),
            for (final f in outgoing)
              ListTile(
                title: Text(f.other.label),
                subtitle: const Text('Demande envoyée'),
                trailing: TextButton(
                  onPressed: () => _act(() => repo.removeFriend(f.other.id), 'Demande annulée'),
                  child: const Text('Annuler'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GroupsTab extends StatefulWidget {
  const _GroupsTab();

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  late Future<List<RunGroup>> _groups;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _groups = context.read<SocialRepository>().myGroups());

  Future<String?> _ask(String title, String label) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);
    return FutureBuilder<List<RunGroup>>(
      future: _groups,
      builder: (context, snap) {
        final groups = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.group_add),
                  label: const Text('Créer'),
                  onPressed: () async {
                    final name = await _ask('Nouveau groupe', 'Nom du groupe');
                    if (name == null || name.trim().isEmpty) return;
                    await repo.createGroup(name);
                    _reload();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.vpn_key),
                  label: const Text('Rejoindre'),
                  onPressed: () async {
                    final code = await _ask('Rejoindre un groupe', "Code d'invitation");
                    if (code == null || code.trim().isEmpty) return;
                    final err = await repo.joinGroup(code);
                    messenger.showSnackBar(SnackBar(content: Text(err ?? 'Groupe rejoint !')));
                    _reload();
                  },
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (snap.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (groups.isEmpty)
              const Text('Crée un groupe pour ton club ou tes potes, puis partage le code.'),
            for (final g in groups)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(g.name),
                  subtitle: Text('Code : ${g.inviteCode}'),
                  trailing: const Icon(Icons.leaderboard),
                  onTap: () async {
                    await Navigator.push(
                        context, MaterialPageRoute(builder: (_) => GroupDetailScreen(group: g)));
                    _reload();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}
