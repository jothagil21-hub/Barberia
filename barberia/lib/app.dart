import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import 'core/constants/app_branding.dart';

import 'core/notifications/appointment_notification_sync.dart';

import 'core/notifications/notification_service.dart';

import 'core/theme/app_theme.dart';

import 'data/database/database_helper.dart';

import 'data/repositories/appointment_repository.dart';

import 'providers/providers.dart';

import 'router.dart';
import 'widgets/sync_lifecycle_listener.dart';



class BarberiaApp extends ConsumerWidget {

  const BarberiaApp({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final router = ref.watch(routerProvider);

    final settings = ref.watch(appSettingsProvider);



    final title = settings.maybeWhen(

      data: (value) => value.appDisplayName,

      orElse: () => AppBranding.appDisplayName,

    );



    return SyncLifecycleListener(
      child: MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      ),
    );

  }

}



Future<void> bootstrap() async {

  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper.instance.database;

  await NotificationService.instance.initialize();

  await resyncAllAppointmentReminders(AppointmentRepository());

}

