import 'package:path/path.dart';

import 'package:sqflite/sqflite.dart';



import '../../core/security/password_hasher.dart';

import 'database_seeder.dart';

import 'schema.dart';



class DatabaseHelper {

  DatabaseHelper._([this._injectedDatabase]);



  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  final Database? _injectedDatabase;



  factory DatabaseHelper.forTesting(Database database) {

    return DatabaseHelper._(database);

  }



  Future<Database> get database async {

    if (_injectedDatabase != null) return _injectedDatabase!;

    _database ??= await _initDatabase();

    return _database!;

  }



  Future<Database> _initDatabase() async {

    final dbPath = await getDatabasesPath();

    final path = join(dbPath, 'barberia.db');



    return openDatabase(

      path,

      version: Schema.version,

      onCreate: _onCreate,

      onUpgrade: _onUpgrade,

    );

  }



  Future<void> _onCreate(Database db, int version) async {

    await db.execute(Schema.createServices);

    await db.execute(Schema.createBarbers);

    await db.execute(Schema.createUsers);

    await db.execute(Schema.createAppSettings);

    await db.execute(Schema.createAppointments);

    await db.execute(Schema.createAppointmentServices);

    await db.execute(Schema.createPosInvoices);

    await db.execute(Schema.createBarberScheduleBlocks);

    await db.execute(Schema.createBarberFullDayBlockIndex);

    await db.execute(Schema.createBarberSlotBlockIndex);

    await db.execute(Schema.createSchemaMeta);

    await db.execute(Schema.createSyncQueue);



    await DatabaseSeeder.seedCoreData(db);



    await db.insert('schema_meta', {

      'key': 'version',

      'value': Schema.version.toString(),

    });

  }



  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {

    if (oldVersion < 2) {

      await db.execute(Schema.createBarbers);

      await db.execute(Schema.createUsers);



      for (final name in Schema.defaultBarbers) {

        await db.insert('barbers', {'name': name, 'is_active': 1});

      }



      await db.insert('users', {

        'username': Schema.defaultAdminUsername,

        'password_hash': PasswordHasher.hash(Schema.defaultAdminPassword),

        'role': Schema.defaultAdminRole,

        'created_at': DateTime.now().toIso8601String(),

        'password_change_count': 0,

      });



      await db.execute(

        'ALTER TABLE appointments ADD COLUMN barber_id INTEGER NOT NULL DEFAULT 1',

      );

      await db.execute(Schema.dropActiveSlotIndex);

      await db.execute(Schema.createActiveSlotIndex);

    }



    if (oldVersion < 3) {

      await db.execute(Schema.createAppSettings);

      await DatabaseSeeder.seedAppSettings(db);

      await db.execute(

        'ALTER TABLE users ADD COLUMN password_change_count INTEGER NOT NULL DEFAULT 0',

      );

    }



    if (oldVersion < 4) {

      await db.execute(

        'ALTER TABLE services ADD COLUMN price REAL NOT NULL DEFAULT 0',

      );

      await db.execute(

        'ALTER TABLE appointment_services ADD COLUMN unit_price REAL NOT NULL DEFAULT 0',

      );

      await db.rawUpdate('''

        UPDATE appointment_services

        SET unit_price = (

          SELECT price FROM services WHERE services.id = appointment_services.service_id

        )

      ''');

      await db.execute(Schema.createBarberScheduleBlocks);

      await db.execute(Schema.createBarberFullDayBlockIndex);

      await db.execute(Schema.createBarberSlotBlockIndex);

    }



    if (oldVersion < 4) {

      await db.update(

        'schema_meta',

        {'value': Schema.version.toString()},

        where: 'key = ?',

        whereArgs: ['version'],

      );

    }

    if (oldVersion < 5) {
      await DatabaseSeeder.seedScheduleSettings(db);
      await db.update(
        'schema_meta',
        {'value': Schema.version.toString()},
        where: 'key = ?',
        whereArgs: ['version'],
      );
    }

    if (oldVersion < 6) {
      final now = DateTime.now().toIso8601String();
      for (final sql in [
        'ALTER TABLE barbers ADD COLUMN server_id TEXT',
        'ALTER TABLE barbers ADD COLUMN updated_at TEXT NOT NULL DEFAULT ""',
        'ALTER TABLE barbers ADD COLUMN sync_status TEXT NOT NULL DEFAULT "synced"',
        'ALTER TABLE services ADD COLUMN server_id TEXT',
        'ALTER TABLE services ADD COLUMN updated_at TEXT NOT NULL DEFAULT ""',
        'ALTER TABLE services ADD COLUMN sync_status TEXT NOT NULL DEFAULT "synced"',
        'ALTER TABLE appointments ADD COLUMN server_id TEXT',
        'ALTER TABLE appointments ADD COLUMN updated_at TEXT NOT NULL DEFAULT ""',
        'ALTER TABLE appointments ADD COLUMN sync_status TEXT NOT NULL DEFAULT "synced"',
        'ALTER TABLE barber_schedule_blocks ADD COLUMN server_id TEXT',
        'ALTER TABLE barber_schedule_blocks ADD COLUMN updated_at TEXT NOT NULL DEFAULT ""',
        'ALTER TABLE barber_schedule_blocks ADD COLUMN sync_status TEXT NOT NULL DEFAULT "synced"',
      ]) {
        await db.execute(sql);
      }
      await db.execute(Schema.createSyncQueue);
      await db.rawUpdate('UPDATE barbers SET updated_at = ? WHERE updated_at = ""', [now]);
      await db.rawUpdate('UPDATE services SET updated_at = ? WHERE updated_at = ""', [now]);
      await db.rawUpdate('UPDATE appointments SET updated_at = ? WHERE updated_at = ""', [now]);
      await db.rawUpdate(
        'UPDATE barber_schedule_blocks SET updated_at = ? WHERE updated_at = ""',
        [now],
      );
      await db.update(
        'schema_meta',
        {'value': Schema.version.toString()},
        where: 'key = ?',
        whereArgs: ['version'],
      );
    }

    if (oldVersion < 7) {
      await db.execute('ALTER TABLE users ADD COLUMN tenant_user_id TEXT');
      await db.execute(
        'ALTER TABLE users ADD COLUMN auth_source TEXT NOT NULL DEFAULT "${Schema.authSourceLocal}"',
      );
      await db.update(
        'schema_meta',
        {'value': Schema.version.toString()},
        where: 'key = ?',
        whereArgs: ['version'],
      );
    }

    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE services ADD COLUMN duration_minutes INTEGER NOT NULL DEFAULT 30',
      );
      await db.execute(
        'ALTER TABLE appointments ADD COLUMN duration_minutes INTEGER NOT NULL DEFAULT 30',
      );
      await db.execute(
        'ALTER TABLE appointment_services ADD COLUMN duration_minutes INTEGER NOT NULL DEFAULT 30',
      );
      await db.execute(Schema.dropActiveSlotIndex);
      await db.execute(Schema.createPosInvoices);
      await db.update(
        'schema_meta',
        {'value': Schema.version.toString()},
        where: 'key = ?',
        whereArgs: ['version'],
      );
    }

    if (oldVersion < 9) {
      await db.insert(
        'app_settings',
        {'key': Schema.settingLogoServerUrl, 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await db.update(
        'schema_meta',
        {'value': Schema.version.toString()},
        where: 'key = ?',
        whereArgs: ['version'],
      );
    }
  }
}

