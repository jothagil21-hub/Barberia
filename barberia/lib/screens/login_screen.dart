import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/api/api_config.dart';
import '../core/constants/app_branding.dart';
import '../core/sync/sync_session_store.dart';
import '../core/theme/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/app_section_title.dart';
import '../widgets/shop_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _scrollController = ScrollController();
  final _statusKey = GlobalKey();

  final _apiUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localUsernameController = TextEditingController(text: 'admin');
  final _localPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showLocalBackup = false;
  bool _loading = false;
  bool _testingHealth = false;
  String? _phase;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _loadLastLinkForm();
  }

  Future<void> _loadLastLinkForm() async {
    final form = await SyncSessionStore().readLastLinkForm();
    if (!mounted || form == null) return;
    setState(() {
      _apiUrlController.text = form.apiBaseUrl;
      _usernameController.text = form.username;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _apiUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _localUsernameController.dispose();
    _localPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _scrollToStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _statusKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _submit() async {
    final rawUrl = _apiUrlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _error = 'Indica la URL del servidor (IP de tu PC en Wi‑Fi).';
        _info = null;
      });
      _scrollToStatus();
      return;
    }

    setState(() {
      _loading = true;
      _phase = 'connecting';
      _error = null;
      _info = 'Conectando…';
    });
    _scrollToStatus();

    final message = await ref.read(authProvider.notifier).loginWithPanel(
          apiBaseUrl: rawUrl,
          username: _usernameController.text,
          password: _passwordController.text,
          onPhase: (phase) {
            if (!mounted) return;
            setState(() {
              _phase = phase;
              _info = phase == 'syncing'
                  ? 'Sincronizando datos con el panel…'
                  : 'Conectando con el servidor…';
            });
          },
        );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _phase = null;
      _info = null;
    });

    if (ref.read(authProvider).value == null) {
      setState(() => _error = message ?? 'No se pudo iniciar sesión.');
      _scrollToStatus();
      return;
    }

    if (message != null) {
      _showSnackBar('Sesión iniciada. $message', isError: false);
    } else {
      _showSnackBar('Sesión iniciada correctamente', isError: false);
    }
    context.go('/');
  }

  Future<void> _submitLocal() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await ref.read(authProvider.notifier).loginLocal(
          _localUsernameController.text,
          _localPasswordController.text,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    context.go('/');
  }

  Future<void> _testConnection() async {
    final rawUrl = _apiUrlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _error = 'Indica la URL del servidor.';
        _info = null;
      });
      _scrollToStatus();
      return;
    }

    setState(() {
      _testingHealth = true;
      _error = null;
      _info = 'Probando conexión con el servidor…';
    });
    _scrollToStatus();

    try {
      final client = ApiClient();
      client.configure(baseUrl: rawUrl);
      await client.get('/health');
      if (!mounted) return;
      setState(() {
        _info = 'Servidor alcanzable. Puedes iniciar sesión.';
        _error = null;
      });
      _showSnackBar('Servidor alcanzable', isError: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _info = null;
      });
      _showSnackBar(e.message, isError: true);
      _scrollToStatus();
    } catch (e) {
      if (!mounted) return;
      final msg = 'No se pudo probar la conexión: $e';
      setState(() {
        _error = msg;
        _info = null;
      });
      _showSnackBar(msg, isError: true);
      _scrollToStatus();
    } finally {
      if (mounted) setState(() => _testingHealth = false);
    }
  }

  Widget _buildStatusBanner(BuildContext context) {
    if (_error != null) {
      return Container(
        key: _statusKey,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.error),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      );
    }

    if (_info != null) {
      return Container(
        key: _statusKey,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (_loading || _testingHealth)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(_info!)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  bool get _anyActionInProgress => _loading || _testingHealth;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final settings = ref.watch(appSettingsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );
    final shopName = settings?.shopName ?? AppBranding.shopName;
    final logoPath = settings?.logoPath;

    if (auth.isLoading && !_anyActionInProgress) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ShopLogo(
                          logoPath: logoPath,
                          cacheKey: settings?.logoCacheKey,
                          radius: 32,
                          iconSize: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        shopName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inicia sesión con tu usuario del panel',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 24),
                      const AppSectionTitle('Acceso'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL del servidor',
                          hintText: 'http://192.168.1.17:3001',
                          prefixIcon: Icon(Icons.cloud_outlined),
                          helperText:
                              'IP de tu PC en Wi‑Fi. Sin conexión usarás credenciales guardadas.',
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enabled: !_anyActionInProgress,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _anyActionInProgress ? null : _testConnection,
                          icon: _testingHealth
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label: Text(_testingHealth ? 'Probando…' : 'Probar conexión'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Usuario (panel)',
                          prefixIcon: Icon(Icons.person_outline),
                          helperText:
                              'Créalo en Panel → Barbería → Usuarios de app.',
                        ),
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enabled: !_anyActionInProgress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        onSubmitted: (_) => _submit(),
                        enabled: !_anyActionInProgress,
                      ),
                      if (_error != null || _info != null) ...[
                        const SizedBox(height: 12),
                        _buildStatusBanner(context),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _anyActionInProgress ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _loading
                              ? (_phase == 'syncing'
                                  ? 'Sincronizando…'
                                  : 'Conectando…')
                              : 'Iniciar sesión',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _anyActionInProgress
                            ? null
                            : () => setState(() => _showLocalBackup = !_showLocalBackup),
                        child: Text(
                          _showLocalBackup
                              ? 'Ocultar modo local'
                              : 'Modo local de respaldo (admin)',
                        ),
                      ),
                      if (_showLocalBackup) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Solo para uso sin panel. Credenciales por defecto: admin / 123',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _localUsernameController,
                          decoration: const InputDecoration(
                            labelText: 'Usuario local',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          enabled: !_anyActionInProgress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _localPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña local',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                          onSubmitted: (_) => _submitLocal(),
                          enabled: !_anyActionInProgress,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _anyActionInProgress ? null : _submitLocal,
                          icon: const Icon(Icons.offline_bolt),
                          label: const Text('Entrar en modo local'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
