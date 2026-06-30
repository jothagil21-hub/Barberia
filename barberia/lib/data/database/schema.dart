class Schema {
  static const int version = 9;

  static const String createServices = '''
    CREATE TABLE services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      price REAL NOT NULL DEFAULT 0,
      duration_minutes INTEGER NOT NULL DEFAULT 30,
      is_active INTEGER NOT NULL DEFAULT 1,
      server_id TEXT,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced'
    )
  ''';

  static const String createBarbers = '''
    CREATE TABLE barbers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      server_id TEXT,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced'
    )
  ''';

  static const String createUsers = '''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL,
      created_at TEXT NOT NULL,
      password_change_count INTEGER NOT NULL DEFAULT 0,
      tenant_user_id TEXT,
      auth_source TEXT NOT NULL DEFAULT 'local'
    )
  ''';

  static const String authSourceLocal = 'local';
  static const String authSourcePanel = 'panel';

  static const String createAppSettings = '''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const String createAppointments = '''
    CREATE TABLE appointments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_name TEXT NOT NULL,
      barber_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      time TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL DEFAULT 30,
      status TEXT NOT NULL DEFAULT 'scheduled',
      created_at TEXT NOT NULL,
      canceled_at TEXT,
      server_id TEXT,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      FOREIGN KEY (barber_id) REFERENCES barbers(id)
    )
  ''';

  static const String createAppointmentServices = '''
    CREATE TABLE appointment_services (
      appointment_id INTEGER NOT NULL,
      service_id INTEGER NOT NULL,
      unit_price REAL NOT NULL DEFAULT 0,
      duration_minutes INTEGER NOT NULL DEFAULT 30,
      PRIMARY KEY (appointment_id, service_id),
      FOREIGN KEY (appointment_id) REFERENCES appointments(id),
      FOREIGN KEY (service_id) REFERENCES services(id)
    )
  ''';

  static const String createPosInvoices = '''
    CREATE TABLE pos_invoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      appointment_id INTEGER NOT NULL UNIQUE,
      number INTEGER NOT NULL,
      issued_at TEXT NOT NULL,
      client_name TEXT NOT NULL,
      barber_name TEXT,
      subtotal REAL NOT NULL,
      lines_json TEXT NOT NULL,
      server_id TEXT,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      FOREIGN KEY (appointment_id) REFERENCES appointments(id)
    )
  ''';

  static const String createBarberScheduleBlocks = '''
    CREATE TABLE barber_schedule_blocks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      barber_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      time TEXT,
      is_full_day INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      server_id TEXT,
      updated_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      FOREIGN KEY (barber_id) REFERENCES barbers(id)
    )
  ''';

  static const String createBarberFullDayBlockIndex = '''
    CREATE UNIQUE INDEX idx_barber_full_day_block
    ON barber_schedule_blocks(barber_id, date)
    WHERE is_full_day = 1
  ''';

  static const String createBarberSlotBlockIndex = '''
    CREATE UNIQUE INDEX idx_barber_slot_block
    ON barber_schedule_blocks(barber_id, date, time)
    WHERE is_full_day = 0
  ''';

  static const String createSchemaMeta = '''
    CREATE TABLE schema_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const String createActiveSlotIndex = '''
    CREATE UNIQUE INDEX idx_active_appointment_slot
    ON appointments(barber_id, date, time)
    WHERE status = 'scheduled'
  ''';

  static const String createSyncQueue = '''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_local_id INTEGER NOT NULL,
      operation TEXT NOT NULL DEFAULT 'upsert',
      payload_json TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  static const String syncStatusSynced = 'synced';
  static const String syncStatusPending = 'pending';
  static const String syncStatusConflict = 'conflict';

  static const String metaSettingsUpdatedAt = 'settings_updated_at';
  static const String metaLogoPendingUpload = 'logo_pending_upload';
  static const String metaLogoPendingDelete = 'logo_pending_delete';

  static const String migrateV6Barbers = '''
    ALTER TABLE barbers ADD COLUMN server_id TEXT;
    ALTER TABLE barbers ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';
    ALTER TABLE barbers ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced';
  ''';

  static const String migrateV6Services = '''
    ALTER TABLE services ADD COLUMN server_id TEXT;
    ALTER TABLE services ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';
    ALTER TABLE services ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced';
  ''';

  static const String migrateV6Appointments = '''
    ALTER TABLE appointments ADD COLUMN server_id TEXT;
    ALTER TABLE appointments ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';
    ALTER TABLE appointments ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced';
  ''';

  static const String migrateV6Blocks = '''
    ALTER TABLE barber_schedule_blocks ADD COLUMN server_id TEXT;
    ALTER TABLE barber_schedule_blocks ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';
    ALTER TABLE barber_schedule_blocks ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced';
  ''';

  static const String dropActiveSlotIndex =
      'DROP INDEX IF EXISTS idx_active_appointment_slot';

  static const String settingShopName = 'shop_name';
  static const String settingLogoPath = 'logo_path';
  static const String settingLogoServerUrl = 'logo_server_url';
  static const String settingAppDisplayName = 'app_display_name';
  static const String settingScheduleStart = 'schedule_start_time';
  static const String settingScheduleEnd = 'schedule_end_time';
  static const String settingScheduleInterval = 'schedule_interval_minutes';

  static const String defaultShopName = 'Barber Shop';
  static const String defaultAppDisplayName = 'Barbería';

  static const List<String> defaultServices = [
    'Corte sencillo',
    'Corte + barba',
    'Cejas',
    'Barba',
    'Degradado / diseño',
  ];

  static const List<String> defaultBarbers = [
    'Barbero 1',
    'Barbero 2',
  ];

  static const String defaultAdminUsername = 'admin';
  static const String defaultAdminPassword = '123';
  static const String defaultAdminRole = 'admin';
}
