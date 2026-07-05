import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../data/models/app_settings.dart';
import '../data/models/schedule_config.dart';
import '../data/repositories/auth_repository.dart';
import '../providers/providers.dart';
import '../widgets/app_section_title.dart';
import '../widgets/shop_logo.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _shopNameController = TextEditingController();
  final _appNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _masterKeyController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _obscureMaster = true;
  bool _savingShop = false;
  bool _savingAppName = false;
  bool _pickingLogo = false;
  bool _changingPassword = false;
  int? _passwordChangeCount;
  bool _controllersInitialized = false;
  bool _scheduleInitialized = false;
  bool _savingSchedule = false;
  String _scheduleStart = ScheduleConfig.defaults().startTime;
  String _scheduleEnd = ScheduleConfig.defaults().endTime;
  int _scheduleInterval = ScheduleConfig.defaults().intervalMinutes;

  @override
  void initState() {
    super.initState();
    _loadPasswordChangeCount();
  }

  Future<void> _loadPasswordChangeCount() async {
    final session = ref.read(authProvider).value;
    if (session == null || session.isRemote) return;

    final count = await ref
        .read(authRepositoryProvider)
        .getPasswordChangeCount(session.userId);
    if (mounted) setState(() => _passwordChangeCount = count);
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _appNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _masterKeyController.dispose();
    super.dispose();
  }

  void _syncControllers(AppSettings settings) {
    if (!_controllersInitialized) {
      _shopNameController.text = settings.shopName;
      _appNameController.text = settings.appDisplayName;
      _controllersInitialized = true;
    } else {
      if (!_savingShop &&
          !_pickingLogo &&
          _shopNameController.text != settings.shopName) {
        _shopNameController.text = settings.shopName;
      }
      if (!_savingAppName &&
          _appNameController.text != settings.appDisplayName) {
        _appNameController.text = settings.appDisplayName;
      }
    }
    if (!_scheduleInitialized) {
      _scheduleStart = settings.scheduleConfig.startTime;
      _scheduleEnd = settings.scheduleConfig.endTime;
      _scheduleInterval = settings.scheduleConfig.intervalMinutes;
      _scheduleInitialized = true;
    } else if (!_savingSchedule) {
      _scheduleStart = settings.scheduleConfig.startTime;
      _scheduleEnd = settings.scheduleConfig.endTime;
      _scheduleInterval = settings.scheduleConfig.intervalMinutes;
    }
  }

  Future<void> _pickScheduleTime({required bool isStart}) async {
    final current = isStart ? _scheduleStart : _scheduleEnd;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );

    if (picked == null || !mounted) return;

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _scheduleStart = formatted;
      } else {
        _scheduleEnd = formatted;
      }
    });
  }

  Future<void> _saveSchedule() async {
    setState(() => _savingSchedule = true);
    try {
      await ref.read(appSettingsProvider.notifier).updateScheduleConfig(
            ScheduleConfig(
              startTime: _scheduleStart,
              endTime: _scheduleEnd,
              intervalMinutes: _scheduleInterval,
            ),
          );
      if (!mounted) return;
      setState(() => _scheduleInitialized = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horario de agenda actualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingSchedule = false);
    }
  }

  Future<void> _saveShopName() async {
    setState(() => _savingShop = true);
    try {
      await ref
          .read(appSettingsProvider.notifier)
          .updateShopName(_shopNameController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre de barbería actualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingShop = false);
    }
  }

  Future<void> _saveAppName() async {
    setState(() => _savingAppName = true);
    try {
      await ref
          .read(appSettingsProvider.notifier)
          .updateAppDisplayName(_appNameController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre de la app actualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingAppName = false);
    }
  }

  Future<void> _pickLogo() async {
    setState(() => _pickingLogo = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;

      final warning = await ref
          .read(appSettingsProvider.notifier)
          .saveLogo(File(image.path));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning ?? 'Logo actualizado.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al elegir logo: $error')),
      );
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    try {
      final warning =
          await ref.read(appSettingsProvider.notifier).clearLogo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(warning ?? 'Logo eliminado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _changePassword() async {
    final session = ref.read(authProvider).value;
    if (session == null) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La confirmación no coincide.')),
      );
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            userId: session.userId,
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
            masterKey: _masterKeyController.text.isEmpty
                ? null
                : _masterKeyController.text,
          );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _masterKeyController.clear();
      await _loadPasswordChangeCount();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada.')),
      );
    } on InvalidPasswordException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña actual es incorrecta.')),
      );
    } on MasterKeyRequiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se requiere la clave maestra para cambiar la contraseña.',
          ),
        ),
      );
    } on ArgumentError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? error.toString())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).value;
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (settings) {
          _syncControllers(settings);
          final requiresMasterKey = (_passwordChangeCount ?? 0) >= 1;
          final canEditCompanySettings =
              auth?.isRemote != true || (auth?.isOwner ?? false);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (auth?.isRemote == true)
                Card(
                  color: AppTheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      auth!.isOwner
                          ? 'Barbería vinculada al panel. Los cambios se sincronizan al tener conexión.'
                          : 'Barbería vinculada. Branding y horario se gestionan desde el panel.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              if (auth?.isRemote == true) const SizedBox(height: 12),
              const AppSectionTitle('Empresa'),
              const SizedBox(height: 12),
              Center(
                child: ShopLogo(
                  logoPath: settings.logoPath,
                  cacheKey: settings.logoCacheKey,
                  radius: 40,
                  iconSize: 36,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _shopNameController,
                enabled: canEditCompanySettings,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la barbería',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !canEditCompanySettings || _pickingLogo
                          ? null
                          : _pickLogo,
                      icon: _pickingLogo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined),
                      label: const Text('Elegir logo'),
                    ),
                  ),
                  if (settings.logoPath != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Quitar logo',
                      onPressed: canEditCompanySettings ? _removeLogo : null,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: !canEditCompanySettings || _savingShop
                    ? null
                    : _saveShopName,
                child: Text(_savingShop ? 'Guardando...' : 'Guardar empresa'),
              ),
              const SizedBox(height: 32),
              const AppSectionTitle('Aplicación'),
              const SizedBox(height: 12),
              TextField(
                controller: _appNameController,
                enabled: canEditCompanySettings,
                decoration: const InputDecoration(
                  labelText: 'Nombre visible en la app',
                  prefixIcon: Icon(Icons.badge_outlined),
                  helperText: 'No cambia el nombre bajo el icono en Android.',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: !canEditCompanySettings || _savingAppName
                    ? null
                    : _saveAppName,
                child: Text(_savingAppName ? 'Guardando...' : 'Guardar nombre'),
              ),
              const SizedBox(height: 32),
              const AppSectionTitle('Agenda'),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora de inicio'),
                subtitle: const Text('Primera franja disponible'),
                trailing: Text(
                  _scheduleStart,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: !canEditCompanySettings || _savingSchedule
                    ? null
                    : () => _pickScheduleTime(isStart: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora de cierre'),
                subtitle: const Text('Última franja del día'),
                trailing: Text(
                  _scheduleEnd,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: !canEditCompanySettings || _savingSchedule
                    ? null
                    : () => _pickScheduleTime(isStart: false),
              ),
              const SizedBox(height: 8),
              DropdownMenu<int>(
                initialSelection: _scheduleInterval,
                label: const Text('Duración de cada cita'),
                dropdownMenuEntries: ScheduleConfig.allowedIntervals
                    .map(
                      (minutes) => DropdownMenuEntry(
                        value: minutes,
                        label: '$minutes minutos',
                      ),
                    )
                    .toList(),
                onSelected: !canEditCompanySettings || _savingSchedule
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _scheduleInterval = value);
                      },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: !canEditCompanySettings || _savingSchedule
                    ? null
                    : _saveSchedule,
                child: Text(
                  _savingSchedule ? 'Guardando...' : 'Guardar horario de agenda',
                ),
              ),
              const SizedBox(height: 32),
              const AppSectionTitle('Cuenta'),
              const SizedBox(height: 12),
              if (auth != null)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  child: Text(auth.username),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                obscureText: _obscureCurrent,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                obscureText: _obscureNew,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
              ),
              if (requiresMasterKey) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _masterKeyController,
                  decoration: InputDecoration(
                    labelText: 'Clave maestra',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    helperText:
                        'Requerida desde el segundo cambio de contraseña.',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureMaster
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureMaster = !_obscureMaster),
                    ),
                  ),
                  obscureText: _obscureMaster,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _changingPassword ? null : _changePassword,
                icon: _changingPassword
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.password),
                label: Text(
                  _changingPassword ? 'Actualizando...' : 'Cambiar contraseña',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
