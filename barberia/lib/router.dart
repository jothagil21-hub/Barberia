import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/appointment_detail_screen.dart';
import 'screens/barbers_management_screen.dart';
import 'screens/canceled_appointments_screen.dart';
import 'screens/export_appointments_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_appointment_screen.dart';
import 'screens/reschedule_appointment_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/schedule_block_screen.dart';
import 'screens/services_management_screen.dart';
import 'providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (auth.isLoading) return null;

      final loggedIn = auth.value != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!loggedIn && !isLoginRoute) return '/login';
      if (loggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/new',
        builder: (context, state) => const NewAppointmentScreen(),
      ),
      GoRoute(
        path: '/canceled',
        builder: (context, state) => const CanceledAppointmentsScreen(),
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) => const ServicesManagementScreen(),
      ),
      GoRoute(
        path: '/barbers',
        builder: (context, state) => const BarbersManagementScreen(),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportAppointmentsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileSettingsScreen(),
      ),
      GoRoute(
        path: '/schedule-block',
        builder: (context, state) => const ScheduleBlockScreen(),
      ),
      GoRoute(
        path: '/appointment/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AppointmentDetailScreen(appointmentId: id);
        },
      ),
      GoRoute(
        path: '/appointment/:id/reschedule',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RescheduleAppointmentScreen(appointmentId: id);
        },
      ),
    ],
  );
});
