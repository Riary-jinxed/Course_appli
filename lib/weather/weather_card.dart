import 'package:flutter/material.dart';

import 'weather.dart';

/// Carte "Météo avant de sortir" de l'accueil.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  Future<Weather>? _weather;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _weather = Weather.here();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Weather>(
      future: _weather,
      builder: (context, snap) {
        if (snap.hasError) {
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Météo indisponible'),
              subtitle: const Text('Active la localisation et Internet, puis touche pour réessayer.'),
              onTap: () => setState(() => _weather = Weather.here()),
            ),
          );
        }
        final w = snap.data;
        if (w == null) {
          return const Card(
            margin: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ListTile(leading: CircularProgressIndicator(), title: Text('Météo…')),
          );
        }
        final tips = outfitAdvice(w);
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${w.temp.round()}°', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${w.description}\nRessenti ${w.feelsLike.round()}° · vent ${w.windKmh.round()} km/h'
                        '${w.rainChance3h > 0 ? ' · pluie ${w.rainChance3h} %' : ''}'),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ]),
                const SizedBox(height: 6),
                Text(tips.first),
                if (_expanded) ...[for (final t in tips.skip(1)) Padding(padding: const EdgeInsets.only(top: 4), child: Text(t))],
                if (!_expanded && tips.length > 1)
                  Text('+ ${tips.length - 1} conseil${tips.length > 2 ? 's' : ''}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        );
      },
    );
  }
}
