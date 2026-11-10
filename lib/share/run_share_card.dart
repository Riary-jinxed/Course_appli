import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/run.dart';
import '../services/geo.dart';

/// Carte visuelle d'une course (tracé + stats), au format carré, à partager.
class RunShareCard extends StatelessWidget {
  final Run run;
  const RunShareCard({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6D3A);
    const fg = Colors.white;
    final km = (run.distanceM / 1000).toStringAsFixed(2).replaceAll('.', ',');
    Widget stat(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(value, style: const TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        );
    return Container(
      width: 360,
      height: 360,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2230), Color(0xFF2D1B2E)],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.directions_run, color: accent, size: 20),
            const SizedBox(width: 6),
            Text(DateFormat('EEEE d MMMM', 'fr_FR').format(run.startedAt),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: CustomPaint(painter: RoutePainter(run.points, run.checkpoints, accent), size: Size.infinite),
            ),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(km, style: const TextStyle(color: fg, fontSize: 44, fontWeight: FontWeight.w800, height: 1)),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text('km', style: TextStyle(color: fg, fontSize: 18)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            stat('Temps', formatDuration(run.movingTime)),
            stat('Allure', '${formatPace(run.avgSpeedMps)}/km'),
            stat('D+', '${run.elevationGainM.round()} m'),
            stat('kcal', run.calories.round().toString()),
          ]),
        ],
      ),
    );
  }
}

/// Dessine le tracé GPS mis à l'échelle (projection équirectangulaire locale).
class RoutePainter extends CustomPainter {
  final List<TrackPoint> points;
  final List<Checkpoint> checkpoints;
  final Color color;
  RoutePainter(this.points, this.checkpoints, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final lat0 = points.first.lat * pi / 180;
    Offset proj(double lat, double lng) => Offset(lng * cos(lat0), -lat);
    final raw = [for (final p in points) proj(p.lat, p.lng)];
    var minX = raw.first.dx, maxX = minX, minY = raw.first.dy, maxY = minY;
    for (final o in raw) {
      minX = min(minX, o.dx);
      maxX = max(maxX, o.dx);
      minY = min(minY, o.dy);
      maxY = max(maxY, o.dy);
    }
    final w = max(maxX - minX, 1e-9), h = max(maxY - minY, 1e-9);
    final scale = min(size.width / w, size.height / h) * 0.92;
    final dx = (size.width - w * scale) / 2, dy = (size.height - h * scale) / 2;
    Offset tr(Offset o) => Offset(dx + (o.dx - minX) * scale, dy + (o.dy - minY) * scale);

    final path = Path()..moveTo(tr(raw.first).dx, tr(raw.first).dy);
    for (final o in raw.skip(1)) {
      final t = tr(o);
      path.lineTo(t.dx, t.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(tr(raw.first), 6, Paint()..color = Colors.greenAccent);
    canvas.drawCircle(tr(raw.last), 6, Paint()..color = Colors.white);
    for (final c in checkpoints) {
      canvas.drawCircle(tr(proj(c.lat, c.lng)), 5, Paint()..color = Colors.amber);
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) => old.points != points;
}

/// Affiche l'aperçu de la carte et la partage (WhatsApp, Instagram…).
Future<void> showShareSheet(BuildContext context, Run run) {
  final key = GlobalKey();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FittedBox(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RepaintBoundary(key: key, child: RunShareCard(run: run)),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Partager (WhatsApp, Insta…)'),
            onPressed: () async {
              final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
              final file = await renderToPng(boundary);
              final km = (run.distanceM / 1000).toStringAsFixed(2).replaceAll('.', ',');
              await SharePlus.instance.share(ShareParams(
                files: [XFile(file.path, mimeType: 'image/png')],
                text: '🏃 $km km en ${formatDuration(run.movingTime)} '
                    '(${formatPace(run.avgSpeedMps)}/km) !',
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    ),
  );
}

Future<File> renderToPng(RenderRepaintBoundary boundary) async {
  final ui.Image image = await boundary.toImage(pixelRatio: 3); // 1080×1080
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/course_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}
