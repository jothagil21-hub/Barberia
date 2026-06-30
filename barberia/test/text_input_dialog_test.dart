import 'package:barberia/widgets/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Cancelar cierra el diálogo sin excepción y retorna null', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showTextInputDialog(
                    context,
                    title: 'Editar cliente',
                    label: 'Nombre del cliente',
                    initialValue: 'Ana',
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Editar cliente'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, isNull);
    expect(find.text('Editar cliente'), findsNothing);
  });

  testWidgets('Guardar con texto válido retorna el valor', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showTextInputDialog(
                    context,
                    title: 'Nuevo barbero',
                    label: 'Nombre del barbero',
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Luis');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, 'Luis');
  });

  testWidgets('Guardar con texto vacío no cierra el diálogo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showTextInputDialog(
                    context,
                    title: 'Nuevo servicio',
                    label: 'Nombre del servicio',
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Nuevo servicio'), findsOneWidget);
  });

  testWidgets('Cancelar en diálogo de servicio no lanza excepción', (
    tester,
  ) async {
    ServiceInputDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showServiceInputDialog(
                    context,
                    title: 'Nuevo servicio',
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, isNull);
  });
}
