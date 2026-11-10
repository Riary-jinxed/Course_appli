import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fonds de carte proposés. Tous gratuits et sans clé d'API.
enum MapStyle {
  /// CARTO Voyager (clair) ou Dark Matter (sombre) : épuré, le tracé ressort.
  plan('Plan', Icons.map_outlined),

  /// OpenTopoMap : courbes de niveau et sentiers, idéal pour le trail.
  relief('Relief', Icons.terrain),

  /// Esri World Imagery : vue satellite.
  satellite('Satellite', Icons.satellite_alt);

  final String label;
  final IconData icon;
  const MapStyle(this.label, this.icon);

  /// Modèle d'URL des tuiles (`{r}` = suffixe haute densité « @2x »).
  String url(Brightness b) => switch (this) {
        plan => b == Brightness.dark
            ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
            : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
        relief => 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
        satellite => 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      };

  int get maxNativeZoom => switch (this) { plan => 20, relief => 17, satellite => 19 };

  /// Le fond est-il sombre (pour choisir la couleur de bordure du tracé) ?
  bool isDark(Brightness b) => this == satellite || (this == plan && b == Brightness.dark);

  String get attribution => switch (this) {
        plan => '© OpenStreetMap · © CARTO',
        relief => '© OpenStreetMap · SRTM · © OpenTopoMap (CC-BY-SA)',
        satellite => '© Esri, Maxar, Earthstar Geographics',
      };
}

/// Fond de carte choisi par l'utilisateur, mémorisé entre les lancements.
class MapStyleSetting extends ValueNotifier<MapStyle> {
  static const _key = 'map_style';
  MapStyleSetting._(super.value);

  static final instance = MapStyleSetting._(MapStyle.plan);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    instance.value = MapStyle.values.firstWhere((s) => s.name == name, orElse: () => MapStyle.plan);
  }

  Future<void> set(MapStyle s) async {
    value = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, s.name);
  }
}
