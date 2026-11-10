import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../map/map_style.dart';
import '../map/pace_colors.dart';
import '../models/run.dart';
import '../theme/app_theme.dart';

/// Carte du parcours : fond adapté à la course, tracé coloré par allure,
/// départ, arrivée, bornes kilométriques et checkpoints.
class RouteMap extends StatelessWidget {
  final List<TrackPoint> points;
  final List<Checkpoint> checkpoints;

  /// Course en direct : la carte suit le coureur et affiche sa position.
  final bool follow;
  final MapController? controller;

  /// Colore le tracé selon l'allure (sinon couleur unie).
  final bool paceColors;

  /// Affiche le sélecteur de fond de carte.
  final bool showStylePicker;

  const RouteMap({
    super.key,
    required this.points,
    this.checkpoints = const [],
    this.follow = false,
    this.controller,
    this.paceColors = true,
    this.showStylePicker = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapStyle>(
      valueListenable: MapStyleSetting.instance,
      builder: (context, style, _) => _build(context, style),
    );
  }

  Widget _build(BuildContext context, MapStyle style) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final darkBase = style.isDark(brightness);
    final line = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final casing = darkBase ? const Color(0xCC0E1320) : Colors.white;

    final options = line.length >= 2 && !follow
        ? MapOptions(
            initialCameraFit: CameraFit.coordinates(coordinates: line, padding: const EdgeInsets.all(40)),
            maxZoom: 19,
          )
        : MapOptions(
            initialCenter: line.isEmpty ? const LatLng(46.6, 2.4) : line.last,
            initialZoom: line.isEmpty ? 5 : 16,
            maxZoom: 19,
          );

    final polylines = <Polyline>[];
    if (line.length >= 2) {
      final segments = paceColors && points.length >= 4 ? paceSegments(points) : const <PaceSegment>[];
      // Contour sous le tracé pour qu'il ressorte sur tous les fonds.
      polylines.add(Polyline(points: line, strokeWidth: 9, color: casing));
      if (segments.isEmpty) {
        polylines.add(Polyline(points: line, strokeWidth: 5, color: scheme.primary));
      } else {
        for (final s in segments) {
          polylines.add(Polyline(points: line.sublist(s.from, s.to + 1), strokeWidth: 5, color: s.color));
        }
      }
    }

    final kms = line.length >= 2 ? kilometerMarks(points) : const <int>[];

    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: options,
          children: [
            ColoredBox(color: darkBase ? AppColors.night : const Color(0xFFF2EFE9)),
            TileLayer(
              urlTemplate: style.url(brightness),
              maxNativeZoom: style.maxNativeZoom,
              retinaMode: style == MapStyle.plan && RetinaMode.isHighDensity(context),
              userAgentPackageName: 'com.riaryjinxed.course_appli',
              tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 150)),
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            MarkerLayer(markers: [
              for (final (i, idx) in kms.indexed)
                Marker(
                  point: line[idx],
                  width: 22,
                  height: 22,
                  child: _KmBadge(km: i + 1, dark: darkBase),
                ),
              for (final (i, c) in checkpoints.indexed)
                Marker(
                  point: LatLng(c.lat, c.lng),
                  width: 28,
                  height: 28,
                  child: _Pin(color: AppColors.gold, child: Text('${i + 1}', style: _pinText(Colors.black))),
                ),
              if (line.length >= 2)
                Marker(
                  point: line.first,
                  width: 26,
                  height: 26,
                  child: const _Pin(color: AppColors.mint, child: Icon(Icons.play_arrow, size: 16, color: Colors.white)),
                ),
              if (line.isNotEmpty && follow)
                Marker(point: line.last, width: 44, height: 44, child: _RunnerDot(color: scheme.primary)),
              if (line.length >= 2 && !follow)
                Marker(
                  point: line.last,
                  width: 26,
                  height: 26,
                  child: const _Pin(color: AppColors.night, child: Icon(Icons.flag, size: 14, color: Colors.white)),
                ),
            ]),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomRight,
              showFlutterMapAttribution: false,
              attributions: [TextSourceAttribution(style.attribution)],
            ),
          ],
        ),
        if (showStylePicker)
          Positioned(top: 12, right: 12, child: _StylePicker(current: style)),
        if (paceColors && points.length >= 4 && !follow)
          const Positioned(left: 12, bottom: 12, child: _PaceLegend()),
      ],
    );
  }
}

TextStyle _pinText(Color c) => TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c, height: 1);

class _Pin extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Pin({required this.color, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Center(child: child),
      );
}

class _KmBadge extends StatelessWidget {
  final int km;
  final bool dark;
  const _KmBadge({required this.km, required this.dark});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? Colors.white : AppColors.night,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Center(
          child: Text('$km',
              style: _pinText(dark ? AppColors.night : Colors.white).copyWith(fontSize: km >= 10 ? 9 : 11)),
        ),
      );
}

/// Position du coureur avec un halo qui « respire ».
class _RunnerDot extends StatefulWidget {
  final Color color;
  const _RunnerDot({required this.color});

  @override
  State<_RunnerDot> createState() => _RunnerDotState();
}

class _RunnerDotState extends State<_RunnerDot> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          Container(
            width: 18 + 26 * _anim.value,
            height: 18 + 26 * _anim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.35 * (1 - _anim.value)),
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6)],
            ),
          ),
        ]),
      );
}

/// Bouton flottant pour changer de fond de carte.
class _StylePicker extends StatelessWidget {
  final MapStyle current;
  const _StylePicker({required this.current});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: PopupMenuButton<MapStyle>(
        tooltip: 'Fond de carte',
        icon: Icon(Icons.layers_outlined, color: scheme.onSurface),
        initialValue: current,
        onSelected: MapStyleSetting.instance.set,
        itemBuilder: (_) => [
          for (final s in MapStyle.values)
            PopupMenuItem(
              value: s,
              child: Row(children: [
                Icon(s.icon, size: 20, color: s == current ? scheme.primary : null),
                const SizedBox(width: 12),
                Text(s.label,
                    style: TextStyle(
                      fontWeight: s == current ? FontWeight.w700 : FontWeight.w500,
                      color: s == current ? scheme.primary : null,
                    )),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Légende « lent → rapide » du tracé coloré.
class _PaceLegend extends StatelessWidget {
  const _PaceLegend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurface);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Lent', style: style),
          const SizedBox(width: 6),
          Container(
            width: 64,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(colors: paceRamp),
            ),
          ),
          const SizedBox(width: 6),
          Text('Rapide', style: style),
        ]),
      ),
    );
  }
}
