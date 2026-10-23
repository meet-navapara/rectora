import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/common/date_key.dart';

void main() {
  final parcels = File('assets/levels/parcels.json').readAsStringSync();
  final threads = File('assets/levels/threads.json').readAsStringSync();
  final daily = File('assets/levels/daily.json').readAsStringSync();
  final traces = File('assets/levels/traces.json').readAsStringSync();
  final inks = File('assets/levels/inks.json').readAsStringSync();
  final catalog = decodeCatalogs(
    parcelsJson: parcels,
    threadsJson: threads,
    dailyJson: daily,
    tracesJson: traces,
    inksJson: inks,
  );

  test('shipped catalogs match the validation report', () {
    expect(catalog.parcels, hasLength(520));
    expect(catalog.threads, hasLength(72));
    expect(catalog.daily, hasLength(120));
    expect(catalog.parcels.first.id, 'parcel-001');
    expect(catalog.parcels.last.id, 'parcel-520');
    expect(catalog.threads.last.id, 'thread-072');
    expect(catalog.traces.length, greaterThanOrEqualTo(20));
    expect(catalog.inks.length, greaterThanOrEqualTo(20));
    expect(catalog.tracePacks, isNotEmpty);
    expect(catalog.inkPacks, isNotEmpty);
    expect(catalog.parcelChapters, hasLength(10));
    expect(catalog.packsFor(false).length, greaterThan(1));
    expect(catalog.packsFor(true), isNotEmpty);
  });

  test('the same local date selects the same daily puzzle', () {
    final morning = DateTime(2026, 10, 21, 1);
    final evening = DateTime(2026, 10, 21, 23, 30);
    expect(
      catalog.dailyLevelFor(morning).id,
      catalog.dailyLevelFor(evening).id,
    );
    expect(
      catalog.dailyLevelFor(DateTime(2026, 10, 22)).id,
      isNot(catalog.dailyLevelFor(morning).id),
    );
    expect(
      dailyPoolIndex(morning, catalog.daily.length),
      inInclusiveRange(0, 119),
    );
  });

  test(
    'every shipped puzzle has one solution',
    () => proveCatalogUnique(catalog),
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
