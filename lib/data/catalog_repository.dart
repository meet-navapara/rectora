import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:rectora/domain/campaign/catalog.dart';

class CatalogRepository {
  static Future<GameCatalog> load() async {
    final loaded = await Future.wait([
      rootBundle.loadString('assets/levels/parcels.json'),
      rootBundle.loadString('assets/levels/threads.json'),
      rootBundle.loadString('assets/levels/daily.json'),
      rootBundle.loadString('assets/levels/traces.json'),
      rootBundle.loadString('assets/levels/inks.json'),
    ]);
    final parcels = loaded[0];
    final threads = loaded[1];
    final daily = loaded[2];
    final traces = loaded[3];
    final inks = loaded[4];
    return Isolate.run(
      () => decodeCatalogs(
        parcelsJson: parcels,
        threadsJson: threads,
        dailyJson: daily,
        tracesJson: traces,
        inksJson: inks,
      ),
    );
  }
}
