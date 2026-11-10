import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'update_service.dart';

/// Bandeau affiché en haut de l'appli quand une nouvelle version est publiée.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<UpdateService>();
    if (!u.showBanner) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.system_update, color: scheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _label(u),
                    style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!u.busy)
                  TextButton(
                    onPressed: u.dismiss,
                    child: const Text('Plus tard'),
                  ),
                FilledButton(
                  onPressed: u.busy ? null : u.update,
                  child: const Text('Mettre à jour'),
                ),
              ]),
              if (u.status == UpdateStatus.downloading)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: LinearProgressIndicator(value: u.progress),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _label(UpdateService u) => switch (u.status) {
        UpdateStatus.downloading =>
          'Téléchargement… ${u.progress == null ? '' : '${(u.progress! * 100).round()} %'}',
        UpdateStatus.needsPermission => 'Autorise l\'installation, puis reviens ici',
        UpdateStatus.error => u.error ?? 'Échec de la mise à jour',
        _ => 'Nouvelle version disponible',
      };
}

/// Écran « Mise à jour » : version installée, dernière version, bouton.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<UpdateService>().check());
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<UpdateService>();
    final text = Theme.of(context).textTheme;
    final latest = u.latest;
    return Scaffold(
      appBar: AppBar(title: const Text('Mise à jour')),
      body: !u.supported
          ? const Center(child: Text('Mise à jour intégrée disponible sur Android uniquement.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: const Text('Version installée'),
                  subtitle: Text(u.installedBuild == null
                      ? '…'
                      : '${u.installedName ?? ''} (build ${u.installedBuild})'.trim()),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Dernière version publiée'),
                  subtitle: Text(latest == null
                      ? (u.status == UpdateStatus.checking ? 'Vérification…' : 'Inconnue')
                      : [
                          'build ${latest.build}',
                          if (latest.date != null) DateFormat('d MMMM yyyy à HH:mm', 'fr_FR').format(latest.date!),
                        ].join(' · ')),
                ),
                if (latest?.notes != null && u.hasUpdate)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('Nouveautés : ${latest!.notes}', style: text.bodyMedium),
                  ),
                const SizedBox(height: 16),
                if (u.status == UpdateStatus.downloading) ...[
                  LinearProgressIndicator(value: u.progress),
                  const SizedBox(height: 8),
                  Text(
                    u.progress == null ? 'Téléchargement…' : 'Téléchargement… ${(u.progress! * 100).round()} %',
                    textAlign: TextAlign.center,
                  ),
                ] else if (u.status == UpdateStatus.checking)
                  const Center(child: CircularProgressIndicator())
                else if (u.hasUpdate)
                  FilledButton.icon(
                    icon: const Icon(Icons.system_update),
                    label: const Text('Mettre à jour'),
                    onPressed: u.update,
                  )
                else if (u.status == UpdateStatus.upToDate)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('L\'appli est à jour', style: text.titleMedium),
                  ]),
                if (u.status == UpdateStatus.needsPermission)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Active « Autoriser cette source » pour Course, puis reviens : '
                      'l\'installation se lance toute seule.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (u.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(u.error!,
                        textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rechercher une mise à jour'),
                  onPressed: u.busy ? null : u.check,
                ),
                const SizedBox(height: 24),
                Text(
                  'Tes courses et réglages sont conservés : la nouvelle version s\'installe par-dessus.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
