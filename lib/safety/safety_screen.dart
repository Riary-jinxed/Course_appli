import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'safety.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  SafetySettings? _s;
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    SafetySettings.load().then((s) => setState(() {
          _s = s;
          _name.text = s.contactName;
          _phone.text = s.contactPhone;
        }));
  }

  Future<void> _save(SafetySettings s) async {
    setState(() => _s = s);
    await s.save();
  }

  SafetySettings _withContact(SafetySettings s) => SafetySettings(
        contactName: _name.text.trim(),
        contactPhone: _phone.text.trim(),
        shareOnStart: s.shareOnStart,
        immobileAlert: s.immobileAlert,
        immobileMinutes: s.immobileMinutes,
      );

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: AppBar(title: const Text('Mode sécurité')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Ton contact d\'urgence reçoit un lien pour suivre ta position en direct sur une carte, '
                  'sans installer l\'appli. Pendant la course, le bouton SOS lui prépare un SMS avec ta position.'),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom du proche'),
                onChanged: (_) => _save(_withContact(s)),
              ),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Téléphone', hintText: '06 12 34 56 78'),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                onChanged: (_) => _save(_withContact(s)),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prévenir à chaque départ'),
                subtitle: const Text('Prépare un SMS avec le lien de suivi en direct au début de chaque course'),
                value: s.shareOnStart,
                onChanged: (v) => _save(SafetySettings(
                    contactName: s.contactName, contactPhone: s.contactPhone, shareOnStart: v,
                    immobileAlert: s.immobileAlert, immobileMinutes: s.immobileMinutes)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alerte si je ne bouge plus'),
                subtitle: Text('Après ${s.immobileMinutes} min sans bouger (hors pause), l\'appli demande si tout va bien '
                    'puis alerte ton proche sans réponse sous 60 s'),
                value: s.immobileAlert,
                onChanged: (v) => _save(SafetySettings(
                    contactName: s.contactName, contactPhone: s.contactPhone, shareOnStart: s.shareOnStart,
                    immobileAlert: v, immobileMinutes: s.immobileMinutes)),
              ),
              if (s.immobileAlert)
                Slider(
                  value: s.immobileMinutes.toDouble(),
                  min: 2,
                  max: 15,
                  divisions: 13,
                  label: '${s.immobileMinutes} min',
                  onChanged: (v) => _save(SafetySettings(
                      contactName: s.contactName, contactPhone: s.contactPhone, shareOnStart: s.shareOnStart,
                      immobileAlert: s.immobileAlert, immobileMinutes: v.round())),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.sms),
                label: const Text('Envoyer un SMS de test'),
                onPressed: s.hasContact
                    ? () => LiveShare.sms(s.contactPhone,
                        'Test de l\'appli Course : tu es mon contact d\'urgence pendant mes sorties 🏃')
                    : null,
              ),
              const SizedBox(height: 8),
              const Text('Le suivi en direct nécessite d\'être connecté (onglet Social). Le lien expire après 24 h. '
                  'L\'SMS n\'est jamais envoyé sans toi : l\'appli l\'ouvre prêt à partir, tu n\'as qu\'à appuyer sur Envoyer.',
                  style: TextStyle(fontSize: 12)),
            ]),
    );
  }
}
