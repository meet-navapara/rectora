import 'package:flutter/material.dart';
import 'package:rectora/domain/progression/relics.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/scope.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final relics = relicsFor(
      stats: controller.stats,
      save: controller.save,
      chapters: controller.catalog.parcelChapters,
      mode: 'parcel',
    );
    final earned = relics.where((relic) => relic.earned).length;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Fragments'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('$earned of ${relics.length} restored'),
          const SizedBox(height: 12),
          for (final relic in relics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                label: relic.earned
                    ? '${relic.title}, restored. ${relic.detail}'
                    : '${relic.title}, still sealed. ${relic.detail}',
                child: Material(
                  color: relic.earned ? palette.surface : palette.backgroundAlt,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: relic.earned ? palette.copper : palette.line,
                    ),
                  ),
                  child: ListTile(
                    title: Text(relic.title),
                    subtitle: Text(relic.detail),
                    trailing: Icon(
                      relic.earned ? Icons.hexagon : Icons.hexagon_outlined,
                      color: relic.earned ? palette.copper : palette.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
