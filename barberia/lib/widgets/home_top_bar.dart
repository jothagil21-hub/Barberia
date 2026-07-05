import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../core/constants/app_branding.dart';

import '../core/theme/app_theme.dart';

import '../core/sync/sync_service.dart';
import '../providers/providers.dart';

import 'shop_logo.dart';



class _NavItem {

  const _NavItem({

    required this.icon,

    required this.label,

    required this.route,

  });



  final IconData icon;

  final String label;

  final String route;

}



const _navItems = [

  _NavItem(

    icon: Icons.groups_outlined,

    label: 'Barberos',

    route: '/barbers',

  ),

  _NavItem(

    icon: Icons.design_services_outlined,

    label: 'Servicios',

    route: '/services',

  ),

  _NavItem(

    icon: Icons.picture_as_pdf_outlined,

    label: 'Exportar',

    route: '/export',

  ),

  _NavItem(

    icon: Icons.history,

    label: 'Canceladas',

    route: '/canceled',

  ),

];



class HomeTopBar extends ConsumerStatefulWidget {

  const HomeTopBar({super.key});



  @override

  ConsumerState<HomeTopBar> createState() => _HomeTopBarState();

}



class _HomeTopBarState extends ConsumerState<HomeTopBar> {

  final _headerKey = GlobalKey();

  OverlayEntry? _overlayEntry;

  bool _menuOpen = false;



  @override

  void dispose() {

    _removeOverlay();

    super.dispose();

  }



  void _removeOverlay() {

    _overlayEntry?.remove();

    _overlayEntry = null;

    _menuOpen = false;

  }



  double get _headerBottom {

    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;

    if (box == null || !box.hasSize) return 0;

    return box.localToGlobal(Offset.zero).dy + box.size.height;

  }



  void _toggleMenu() {

    if (_menuOpen) {

      _removeOverlay();

      setState(() {});

      return;

    }



    final auth = ref.read(authProvider).value;
    final visibleItems = auth?.isStaff == true
        ? _navItems.where((item) => item.route == '/canceled').toList()
        : _navItems;

    _overlayEntry = OverlayEntry(

      builder: (context) {

        final top = _headerBottom;



        return Stack(

          children: [

            Positioned.fill(

              child: GestureDetector(

                onTap: () {

                  _removeOverlay();

                  if (mounted) setState(() {});

                },

                child: ColoredBox(

                  color: Colors.black.withValues(alpha: 0.45),

                ),

              ),

            ),

            Positioned(

              top: top,

              left: 0,

              right: 0,

              child: Material(

                color: AppTheme.surface.withValues(alpha: 0.98),

                elevation: 8,

                child: Padding(

                  padding: const EdgeInsets.symmetric(vertical: 12),

                  child: Row(

                    children: visibleItems.map((item) {

                      return Expanded(

                        child: InkWell(

                          onTap: () {

                            _removeOverlay();

                            if (mounted) setState(() {});

                            context.push(item.route);

                          },

                          child: Padding(

                            padding: const EdgeInsets.symmetric(vertical: 8),

                            child: Column(

                              mainAxisSize: MainAxisSize.min,

                              children: [

                                Icon(item.icon, color: AppTheme.accent),

                                const SizedBox(height: 6),

                                Text(

                                  item.label,

                                  textAlign: TextAlign.center,

                                  style: const TextStyle(

                                    fontSize: 12,

                                    color: AppTheme.textPrimary,

                                  ),

                                ),

                              ],

                            ),

                          ),

                        ),

                      );

                    }).toList(),

                  ),

                ),

              ),

            ),

          ],

        );

      },

    );



    Overlay.of(context).insert(_overlayEntry!);

    setState(() => _menuOpen = true);

  }



  String _syncLabel(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return 'Sincronizando…';
      case SyncState.offline:
        return 'Sin conexión';
      case SyncState.pending:
        return 'Pendiente de sync';
      case SyncState.error:
        return 'Error de sync';
      case SyncState.idle:
        return 'Sincronizado';
    }
  }

  String _syncStatusText(SyncState state, String? syncError) {
    if (syncError != null &&
        (state == SyncState.error ||
            state == SyncState.pending ||
            syncError.contains('citas no se pueden subir'))) {
      return syncError;
    }
    return _syncLabel(state);
  }

  Color _syncStatusColor(BuildContext context, SyncState state, String? syncError) {
    if (state == SyncState.error) {
      return Theme.of(context).colorScheme.error;
    }
    if (state == SyncState.pending &&
        syncError != null &&
        syncError.contains('citas no se pueden subir')) {
      return Theme.of(context).colorScheme.error;
    }
    if (state == SyncState.pending) {
      return AppTheme.accent;
    }
    return AppTheme.accent;
  }

  Future<void> _logout() async {

    _removeOverlay();

    await ref.read(authProvider.notifier).logout();

    if (mounted) context.go('/login');

  }

  Future<void> _manualSync() async {
    final syncState = ref.read(syncStateProvider);
    if (syncState == SyncState.syncing || syncState == SyncState.offline) return;

    final service = ref.read(syncServiceProvider);
    await service.syncNow();

    if (!mounted) return;
    ref.read(appSettingsProvider.notifier).refresh();
    ref.read(barbersRefreshProvider.notifier).refresh();
    ref.read(servicesRefreshProvider.notifier).refresh();
    ref.read(appointmentsRefreshProvider.notifier).refresh();

    final error = service.lastError;
    final state = service.state;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state == SyncState.error && error != null
              ? error
              : state == SyncState.pending
                  ? (error ?? 'Hay cambios pendientes de sincronizar')
                  : 'Sincronización completada',
        ),
        backgroundColor: state == SyncState.error
            ? Theme.of(context).colorScheme.error
            : state == SyncState.pending
                ? AppTheme.accent
                : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }



  @override

  Widget build(BuildContext context) {

    final auth = ref.watch(authProvider).value;
    final syncState = ref.watch(syncStateProvider);
    final syncError = ref.watch(syncServiceProvider).lastError;

    final settings = ref.watch(appSettingsProvider).maybeWhen(

          data: (value) => value,

          orElse: () => null,

        );

    final shopName = settings?.shopName ?? AppBranding.shopName;

    final logoPath = settings?.logoPath;



    return Container(

      key: _headerKey,

      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      color: AppTheme.surface,

      child: Row(

        children: [

          IconButton(

            tooltip: 'Menú',

            icon: Icon(_menuOpen ? Icons.close : Icons.menu),

            color: AppTheme.textPrimary,

            onPressed: _toggleMenu,

          ),

          ShopLogo(
            logoPath: logoPath,
            cacheKey: settings?.logoCacheKey,
            radius: 24,
          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  shopName,

                  style: Theme.of(context).textTheme.titleLarge?.copyWith(

                        fontWeight: FontWeight.bold,

                        color: AppTheme.textPrimary,

                      ),

                ),

                if (auth != null)
                  Text(
                    auth.username,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                if (auth?.isRemote == true)
                  Text(
                    _syncStatusText(syncState, syncError),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _syncStatusColor(context, syncState, syncError),
                          fontSize: 11,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

              ],

            ),

          ),

          if (auth?.isRemote == true)
            IconButton(
              tooltip: 'Sincronizar ahora',
              icon: syncState == SyncState.syncing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent,
                      ),
                    )
                  : const Icon(Icons.sync, color: AppTheme.accent),
              onPressed: syncState == SyncState.syncing ||
                      syncState == SyncState.offline
                  ? null
                  : _manualSync,
            ),

          PopupMenuButton<String>(

            icon: CircleAvatar(

              radius: 20,

              backgroundColor: AppTheme.accent.withValues(alpha: 0.15),

              child: const Icon(Icons.person, color: AppTheme.accent, size: 20),

            ),

            onSelected: (value) {

              if (value == 'profile') context.push('/profile');

              if (value == 'logout') _logout();

            },

            itemBuilder: (context) => [

              if (auth != null)

                PopupMenuItem(

                  enabled: false,

                  child: Text('Sesión: ${auth.username}'),

                ),

              if (auth != null && auth.isOwner)

                const PopupMenuItem(

                  value: 'profile',

                  child: Row(

                    children: [

                      Icon(Icons.settings_outlined, size: 18),

                      SizedBox(width: 8),

                      Text('Configuración'),

                    ],

                  ),

                ),

              const PopupMenuItem(

                value: 'logout',

                child: Row(

                  children: [

                    Icon(Icons.logout, size: 18),

                    SizedBox(width: 8),

                    Text('Cerrar sesión'),

                  ],

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }

}

