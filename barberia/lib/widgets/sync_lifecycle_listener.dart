import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// Escucha red y ciclo de vida para disparar sync automático.
class SyncLifecycleListener extends ConsumerStatefulWidget {
  const SyncLifecycleListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleListener> createState() => _SyncLifecycleListenerState();
}

class _SyncLifecycleListenerState extends ConsumerState<SyncLifecycleListener>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        ref.read(syncServiceProvider).onConnectivityRestored();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(syncServiceProvider).configureFromSession();
      await ref.read(syncServiceProvider).syncNow();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncServiceProvider).syncNow();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
