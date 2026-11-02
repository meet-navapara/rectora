import 'package:flutter/material.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/widgets/ad_banner.dart';
import 'package:rectora/ui/widgets/campaign_map.dart';
import 'package:rectora/ui/controller.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/ui/screens/ink_page.dart';
import 'package:rectora/ui/screens/parcel_page.dart';
import 'package:rectora/ui/screens/thread_page.dart';
import 'package:rectora/ui/screens/trace_page.dart';
import 'package:rectora/ui/widgets/dialogs.dart';

enum CampaignKind { parcel, thread, trace, ink }

class CampaignPage extends StatefulWidget {
  const CampaignPage({super.key, this.kind = CampaignKind.parcel});

  final CampaignKind kind;

  @override
  State<CampaignPage> createState() => _CampaignPageState();
}

class _CampaignPageState extends State<CampaignPage> {
  var noticed = false;

  PlayMode get mode => switch (widget.kind) {
    CampaignKind.parcel => PlayMode.parcel,
    CampaignKind.thread => PlayMode.thread,
    CampaignKind.trace => PlayMode.trace,
    CampaignKind.ink => PlayMode.ink,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (noticed) return;
    noticed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _notice());
  }

  Future<void> _notice() async {
    if (!mounted) return;
    final controller = RectoraScope.read(context);
    final packs = _packs(controller);
    final ids = _ids(controller);
    final open = [
      for (final pack in packs)
        if (pack.levelIds.isNotEmpty &&
            controller.save.unlocked(mode, ids, pack.levelIds.first))
          chapterKey(mode.name, pack.id),
    ];
    // The map already shows which chapters are open, so nothing pops up.
    await controller.seeChapters(open);
  }

  List<PackSummary> _packs(RectoraController controller) {
    return switch (widget.kind) {
      CampaignKind.parcel => controller.catalog.parcelChapters,
      CampaignKind.thread => controller.catalog.packsFor(true),
      CampaignKind.trace => controller.catalog.tracePacks,
      CampaignKind.ink => controller.catalog.inkPacks,
    };
  }

  List<String> _ids(RectoraController controller) {
    return switch (widget.kind) {
      CampaignKind.parcel => controller.catalog.parcelIds,
      CampaignKind.thread => controller.catalog.threadIds,
      CampaignKind.trace => controller.catalog.traceIds,
      CampaignKind.ink => controller.catalog.inkIds,
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final packs = _packs(controller);
    final ids = _ids(controller);
    final records = controller.save.recordsFor(mode);
    final title = switch (widget.kind) {
      CampaignKind.parcel => 'Parcels',
      CampaignKind.thread => 'Threads',
      CampaignKind.trace => 'Trace',
      CampaignKind.ink => 'Inks',
    };
    var currentSet = false;
    final stops = <CampaignStop>[];
    for (final pack in packs) {
      final solved = pack.levelIds
          .where((id) => records[id]?.solved == true)
          .length;
      final locked =
          pack.levelIds.isEmpty ||
          !controller.save.unlocked(mode, ids, pack.levelIds.first);
      final current = !currentSet && !locked && solved < pack.levelIds.length;
      if (current) currentSet = true;
      stops.add(
        CampaignStop(
          pack: pack,
          solved: solved,
          total: pack.levelIds.length,
          locked: locked,
          current: current,
        ),
      );
    }
    return Scaffold(
      backgroundColor: palette.background,
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          CampaignMap(
            stops: stops,
            reduceMotion:
                !controller.save.settings.animations ||
                MediaQuery.disableAnimationsOf(context),
            onOpen: (pack) =>
                pushSoft(context, PackPage(pack: pack, kind: widget.kind)),
          ),
        ],
      ),
    );
  }
}

class PackPage extends StatelessWidget {
  const PackPage({super.key, required this.pack, required this.kind});

  final PackSummary pack;
  final CampaignKind kind;

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final mode = switch (kind) {
      CampaignKind.parcel => PlayMode.parcel,
      CampaignKind.thread => PlayMode.thread,
      CampaignKind.trace => PlayMode.trace,
      CampaignKind.ink => PlayMode.ink,
    };
    final ids = switch (kind) {
      CampaignKind.parcel => controller.catalog.parcelIds,
      CampaignKind.thread => controller.catalog.threadIds,
      CampaignKind.trace => controller.catalog.traceIds,
      CampaignKind.ink => controller.catalog.inkIds,
    };
    String? nextId;
    for (final candidate in pack.levelIds) {
      final open = controller.save.unlocked(mode, ids, candidate);
      final done =
          controller.save.recordsFor(mode)[candidate]?.finished == true;
      if (open && !done) {
        nextId = candidate;
        break;
      }
    }
    return Scaffold(
      backgroundColor: palette.background,
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(
        title: Text(pack.name),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 84,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemCount: pack.levelIds.length,
        itemBuilder: (context, index) {
          final id = pack.levelIds[index];
          final unlocked = controller.save.unlocked(mode, ids, id);
          final record = controller.save.recordsFor(mode)[id];
          final levelNumber = switch (kind) {
            CampaignKind.parcel => controller.catalog.parcelById(id)!.number,
            CampaignKind.thread => controller.catalog.threadById(id)!.number,
            CampaignKind.trace => controller.catalog.traceById(id)!.number,
            CampaignKind.ink => controller.catalog.inkById(id)!.number,
          };
          final difficulty = switch (kind) {
            CampaignKind.parcel =>
              controller.catalog.parcelById(id)!.difficulty,
            CampaignKind.thread =>
              controller.catalog.threadById(id)!.difficulty,
            CampaignKind.trace => controller.catalog.traceById(id)!.difficulty,
            CampaignKind.ink => controller.catalog.inkById(id)!.difficulty,
          };
          return _LevelNode(
            number: levelNumber,
            difficulty: difficulty,
            unlocked: unlocked,
            solved: record?.solved == true,
            perfect: record?.perfect == true,
            skipped: record?.skipped == true,
            current: id == nextId,
            finale: id == pack.levelIds.last,
            onTap: () {
              if (!unlocked) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Finish level ${levelNumber - 1} first.'),
                    ),
                  );
                return;
              }
              final page = switch (kind) {
                CampaignKind.parcel => ParcelPage(
                  level: controller.catalog.parcelById(id)!,
                ),
                CampaignKind.thread => ThreadPage(
                  level: controller.catalog.threadById(id)!,
                ),
                CampaignKind.trace => TracePage(
                  level: controller.catalog.traceById(id)!,
                ),
                CampaignKind.ink => InkPage(
                  level: controller.catalog.inkById(id)!,
                ),
              };
              pushSoft(context, page);
            },
          );
        },
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.number,
    required this.difficulty,
    required this.unlocked,
    required this.solved,
    required this.perfect,
    required this.skipped,
    required this.current,
    required this.finale,
    required this.onTap,
  });

  final int number;
  final Difficulty difficulty;
  final bool unlocked;
  final bool solved;
  final bool perfect;
  final bool skipped;
  final bool current;
  final bool finale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final icon = !unlocked
        ? Icons.lock_outline
        : perfect
        ? Icons.star
        : solved
        ? Icons.check
        : skipped
        ? Icons.fast_forward
        : null;
    final label = !unlocked
        ? 'Locked level $number'
        : perfect
        ? 'Level $number, perfect'
        : solved
        ? 'Level $number, solved'
        : skipped
        ? 'Level $number, skipped'
        : 'Level $number, ${difficulty.label}, available';
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: unlocked ? palette.surface : palette.backgroundAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: current ? palette.copper : palette.line,
            width: current ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon, color: perfect ? palette.copper : palette.ink),
              Text('$number', style: Theme.of(context).textTheme.titleMedium),
              Text(
                finale && unlocked ? 'Finale' : difficulty.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: finale && unlocked ? palette.copper : palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
