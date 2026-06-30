import 'package:barberia/core/theme/app_theme.dart';
import 'package:barberia/core/utils/time_slot_generator.dart';
import 'package:barberia/widgets/time_slot_grid.dart';
import 'package:barberia/widgets/time_slot_legend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('multiSelect aplica estilos distintos a disponible y bloqueado', (
    tester,
  ) async {
    const entries = [
      TimeSlotEntry(time: '09:00', status: TimeSlotStatus.available),
      TimeSlotEntry(time: '10:00', status: TimeSlotStatus.blocked),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: TimeSlotGrid(
            entries: entries,
            selectedSlot: null,
            onSlotSelected: (_) {},
            multiSelect: true,
            selectedSlots: {'10:00'},
            onMultiSelectChanged: (_, __) {},
          ),
        ),
      ),
    );

    final availableChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('slot-available-09:00')),
    );
    final blockedChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('slot-blocked-10:00')),
    );

    expect(availableChip.backgroundColor, AppTheme.slotAvailableBackground);
    expect(availableChip.side?.color, AppTheme.slotAvailableBorder);
    expect(blockedChip.selectedColor, AppTheme.slotBlockedBackground);
    expect(blockedChip.side?.color, AppTheme.slotBlockedBorder);
    expect(availableChip.side?.color, isNot(blockedChip.side?.color));
  });

  testWidgets('TimeSlotLegend modo bloqueo muestra ambos estados', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TimeSlotLegend()),
      ),
    );

    expect(find.byKey(const Key('legend-available')), findsOneWidget);
    expect(find.byKey(const Key('legend-blocked')), findsOneWidget);
    expect(find.text('Toca para bloquear'), findsOneWidget);
    expect(find.text('Toca para desbloquear'), findsOneWidget);
  });

  testWidgets('TimeSlotLegend modo reserva muestra tres estados', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimeSlotLegend(mode: TimeSlotLegendMode.booking),
        ),
      ),
    );

    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Programado'), findsOneWidget);
    expect(find.text('Bloqueado'), findsOneWidget);
    expect(find.text('Puedes reservar'), findsOneWidget);
    expect(find.text('Ya tiene cita'), findsOneWidget);
  });

  testWidgets('modo reserva aplica estilos distintos', (tester) async {
    const entries = [
      TimeSlotEntry(time: '09:00', status: TimeSlotStatus.available),
      TimeSlotEntry(time: '10:00', status: TimeSlotStatus.booked),
      TimeSlotEntry(time: '11:00', status: TimeSlotStatus.blocked),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: TimeSlotGrid(
            entries: entries,
            selectedSlot: null,
            onSlotSelected: (_) {},
          ),
        ),
      ),
    );

    final availableChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('slot-available-09:00')),
    );
    final bookedChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('slot-booked-10:00')),
    );
    final blockedChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('slot-blocked-11:00')),
    );

    expect(availableChip.backgroundColor, AppTheme.slotAvailableBackground);
    expect(bookedChip.backgroundColor, AppTheme.slotBookedBackground);
    expect(blockedChip.backgroundColor, AppTheme.slotBlockedBackground);
    expect(availableChip.side?.color, isNot(bookedChip.side?.color));
    expect(bookedChip.side?.color, isNot(blockedChip.side?.color));
  });
}
