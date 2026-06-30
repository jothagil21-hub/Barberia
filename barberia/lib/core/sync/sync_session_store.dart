import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_config.dart';

class OfflineProfile {
  const OfflineProfile({
    required this.apiBaseUrl,
    required this.tenantId,
    required this.tenantUserId,
    required this.username,
    required this.role,
  });

  final String apiBaseUrl;
  final String tenantId;
  final String tenantUserId;
  final String username;
  final String role;
}

class SyncSessionStore {
  static const _apiUrlKey = 'sync_api_base_url';
  static const _tokenKey = 'sync_auth_token';
  static const _tenantIdKey = 'sync_tenant_id';
  static const _tenantUserIdKey = 'sync_tenant_user_id';
  static const _usernameKey = 'sync_username';
  static const _roleKey = 'sync_role';
  static const _linkedKey = 'sync_is_linked';
  static const _lastSyncKey = 'sync_last_sync_at';
  static const _lastLinkApiUrlKey = 'last_link_api_url';
  static const _lastLinkUsernameKey = 'last_link_username';
  static const _offlineProfileKey = 'sync_offline_profile_saved';
  static const _cachedPasswordKey = 'sync_cached_panel_password';

  Future<bool> get isLinked async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_linkedKey) ?? false;
  }

  Future<String?> get apiBaseUrl async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey);
  }

  Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> get tenantId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tenantIdKey);
  }

  Future<String?> get lastSyncAt async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey);
  }

  Future<String?> get cachedPassword async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cachedPasswordKey);
  }

  Future<void> saveLink({
    required String apiBaseUrl,
    required String token,
    required String tenantId,
    required String tenantUserId,
    required String username,
    required String role,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedUrl = _normalizeUrl(apiBaseUrl);
    await prefs.setString(_apiUrlKey, normalizedUrl);
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_tenantIdKey, tenantId);
    await prefs.setString(_tenantUserIdKey, tenantUserId);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_roleKey, role);
    await prefs.setBool(_linkedKey, true);
    await prefs.setBool(_offlineProfileKey, true);
    if (password != null) {
      await prefs.setString(_cachedPasswordKey, password);
    }
  }

  Future<void> setLastSyncAt(String iso) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, iso);
  }

  Future<void> saveLastLinkForm({
    required String apiBaseUrl,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastLinkApiUrlKey, _normalizeUrl(apiBaseUrl));
    await prefs.setString(_lastLinkUsernameKey, username.trim());
  }

  Future<({String apiBaseUrl, String username})?> readLastLinkForm() async {
    final prefs = await SharedPreferences.getInstance();
    final apiBaseUrl = prefs.getString(_lastLinkApiUrlKey);
    final username = prefs.getString(_lastLinkUsernameKey);
    if (apiBaseUrl == null || username == null) return null;
    return (apiBaseUrl: apiBaseUrl, username: username);
  }

  /// Cierra sesión remota pero conserva perfil offline y credenciales cacheadas.
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.setBool(_linkedKey, false);
  }

  /// Borra toda la sesión incluyendo perfil offline (desvincular barbería).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiUrlKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_tenantIdKey);
    await prefs.remove(_tenantUserIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_offlineProfileKey);
    await prefs.remove(_cachedPasswordKey);
    await prefs.setBool(_linkedKey, false);
  }

  @Deprecated('Use clearToken() for logout or clearAll() to desvincular')
  Future<void> clear() => clearAll();

  Future<({String username, String role, String tenantUserId})?> readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey);
    final role = prefs.getString(_roleKey);
    final userId = prefs.getString(_tenantUserIdKey);
    if (username == null || role == null || userId == null) return null;
    return (username: username, role: role, tenantUserId: userId);
  }

  Future<OfflineProfile?> readOfflineProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_offlineProfileKey) ?? false)) return null;

    final apiBaseUrl = prefs.getString(_apiUrlKey);
    final tenantId = prefs.getString(_tenantIdKey);
    final tenantUserId = prefs.getString(_tenantUserIdKey);
    final username = prefs.getString(_usernameKey);
    final role = prefs.getString(_roleKey);

    if (apiBaseUrl == null ||
        tenantId == null ||
        tenantUserId == null ||
        username == null ||
        role == null) {
      return null;
    }

    return OfflineProfile(
      apiBaseUrl: apiBaseUrl,
      tenantId: tenantId,
      tenantUserId: tenantUserId,
      username: username,
      role: role,
    );
  }

  String _normalizeUrl(String url) => normalizeBaseUrl(url);
}
