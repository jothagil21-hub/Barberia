import 'package:barberia/app.dart';
import 'package:barberia/data/models/app_settings.dart';
import 'package:barberia/data/models/user.dart';
import 'package:barberia/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(userId: 1, username: 'admin', role: 'admin');
  }
}

class _SelectedBarberNotifier extends SelectedBarberIdNotifier {
  @override
  Future<int?> build() async => 1;
}

class _AppSettingsNotifier extends AppSettingsNotifier {
  @override
  Future<AppSettings> build() async => AppSettings.defaults();
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({'selected_barber_id': 1});
  });

  testWidgets('muestra login al iniciar sin sesión', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(_AppSettingsNotifier.new),
        ],
        child: const BarberiaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Barber Shop'), findsOneWidget);
  });

  testWidgets('home no muestra Agenda y el menú despliega opciones', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_LoggedInAuthNotifier.new),
          selectedBarberIdProvider.overrideWith(_SelectedBarberNotifier.new),
          appSettingsProvider.overrideWith(_AppSettingsNotifier.new),
        ],
        child: const BarberiaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agenda'), findsNothing);
    expect(find.text('Barber Shop'), findsOneWidget);
    expect(find.text('Barberos'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Barberos'), findsOneWidget);
    expect(find.text('Servicios'), findsOneWidget);
    expect(find.text('Exportar'), findsOneWidget);
    expect(find.text('Canceladas'), findsOneWidget);
  });
}
