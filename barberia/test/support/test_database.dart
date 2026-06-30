import 'package:barberia/data/database/database_helper.dart';
import 'package:barberia/data/database/database_seeder.dart';
import 'package:barberia/data/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<DatabaseHelper> createTestDatabaseHelper() async {
  final db = await databaseFactory.openDatabase(
    'file:${DateTime.now().microsecondsSinceEpoch}?mode=memory&cache=shared',
    options: OpenDatabaseOptions(
      version: Schema.version,
      onCreate: (database, version) async {
        await database.execute(Schema.createServices);
        await database.execute(Schema.createBarbers);
        await database.execute(Schema.createUsers);
        await database.execute(Schema.createAppSettings);
        await database.execute(Schema.createAppointments);
        await database.execute(Schema.createAppointmentServices);
        await database.execute(Schema.createPosInvoices);
        await database.execute(Schema.createBarberScheduleBlocks);
        await database.execute(Schema.createBarberFullDayBlockIndex);
        await database.execute(Schema.createBarberSlotBlockIndex);
        await database.execute(Schema.createSchemaMeta);
        await DatabaseSeeder.seedCoreData(database);
        await database.insert('schema_meta', {
          'key': 'version',
          'value': Schema.version.toString(),
        });
      },
    ),
  );

  return DatabaseHelper.forTesting(db);
}
