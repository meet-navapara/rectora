import 'package:flutter/material.dart';
import 'package:rectora/data/catalog_repository.dart';
import 'package:rectora/data/key_value_store.dart';
import 'package:rectora/domain/account/account_binder.dart';
import 'package:rectora/domain/account/cloud_types.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/net/online.dart';
import 'package:rectora/domain/settings/settings.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/controller.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/home_page.dart';
import 'package:rectora/ui/screens/start_page.dart';
import 'package:rectora/ui/widgets/dialogs.dart';
import 'package:rectora/ui/widgets/mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RectoraApp extends StatefulWidget {
  const RectoraApp({
    super.key,
    this.catalog,
    this.store,
    this.clock,
    this.cloud,
    this.firebaseBind,
  });

  final GameCatalog? catalog;
  final KeyValueStore? store;
  final DateTime Function()? clock;
  final ProgressCloud? cloud;
  final AccountBinder? firebaseBind;

  @override
  State<RectoraApp> createState() => _RectoraAppState();
}

class _RectoraAppState extends State<RectoraApp> with WidgetsBindingObserver {
  RectoraController? controller;
  Object? error;
  bool? online;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!onlineCheckEnabled) online = true;
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller?.onAppResumed();
      _checkOnline();
    }
  }

  Future<void> _checkOnline() async {
    if (!onlineCheckEnabled) {
      if (mounted) setState(() => online = true);
      return;
    }
    final connected = await deviceIsOnline();
    if (mounted) setState(() => online = connected);
  }

  Future<void> _boot() async {
    try {
      final catalog = widget.catalog ?? await CatalogRepository.load();
      final store =
          widget.store ?? PrefsStore(await SharedPreferences.getInstance());
      final created = RectoraController(
        catalog: catalog,
        store: store,
        clock: widget.clock,
        cloud: widget.cloud,
        firebaseBind: widget.firebaseBind,
      );
      await created.bootstrap();
      if (!mounted) return;
      setState(() {
        controller = created;
        error = null;
      });
      await _checkOnline();
    } catch (caught) {
      if (!mounted) return;
      setState(() => error = caught);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = controller;
    if (error != null) {
      return MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rectora could not open its puzzles.'),
                  const SizedBox(height: 12),
                  Text('$error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _boot,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (created == null) {
      return MaterialApp(
        theme: buildRectoraTheme(RectoraPalette.dark),
        home: const Scaffold(body: Center(child: RectoraMark(size: 72))),
      );
    }
    return AnimatedBuilder(
      animation: created,
      builder: (context, _) {
        if (created.loadError != null) {
          return MaterialApp(
            theme: buildRectoraTheme(RectoraPalette.dark),
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('The local save could not be read.'),
                      const SizedBox(height: 8),
                      const Text(
                        'Rectora did not erase it automatically. You can try again, or erase the local save and start over.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _boot,
                        child: const Text('Try again'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final choice = await showRectoraDialog<bool>(
                            context: context,
                            title: 'Erase the local save?',
                            body: 'Puzzle progress on this device will be removed.',
                            choices: const [
                              DialogChoice(
                                label: 'Erase save',
                                value: true,
                                primary: true,
                              ),
                              DialogChoice(label: 'Cancel', value: false),
                            ],
                          );
                          if (choice == true) {
                            await created.replaceDamagedSave();
                          }
                        },
                        child: const Text('Erase local save'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return RectoraScope(
          controller: created,
          child: MaterialApp(
            title: 'Rectora',
            debugShowCheckedModeBanner: false,
            theme: buildRectoraTheme(RectoraPalette.light),
            darkTheme: buildRectoraTheme(RectoraPalette.dark),
            themeMode: created.save.settings.theme.themeMode,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              final reduce =
                  !created.save.settings.animations || media.disableAnimations;
              return MediaQuery(
                data: media.copyWith(disableAnimations: reduce),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: online != true
                ? online == false
                      ? OfflinePage(onRetry: _checkOnline)
                      : const Scaffold(
                          body: Center(child: RectoraMark(size: 72)),
                        )
                : !created.save.entered && created.save.isGuest
                ? const StartPage()
                : const HomePage(),
          ),
        );
      },
    );
  }
}
