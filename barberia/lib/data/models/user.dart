class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.authSource = 'local',
    this.tenantUserId,
  });

  final int id;
  final String username;
  final String role;
  final String authSource;
  final String? tenantUserId;

  bool get isAdmin => role == 'admin';
  bool get isPanelUser => authSource == 'panel';

  factory AppUser.fromMap(Map<String, Object?> map) {
    return AppUser(
      id: map['id'] as int,
      username: map['username'] as String,
      role: map['role'] as String,
      authSource: map['auth_source'] as String? ?? 'local',
      tenantUserId: map['tenant_user_id'] as String?,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.username,
    required this.role,
    this.tenantId,
    this.remoteUserId,
    this.isRemote = false,
  });

  final int userId;
  final String username;
  final String role;
  final String? tenantId;
  final String? remoteUserId;
  final bool isRemote;

  bool get isOwner => role == 'owner';

  factory AuthSession.fromUser(AppUser user) {
    return AuthSession(
      userId: user.id,
      username: user.username,
      role: user.role,
    );
  }

  factory AuthSession.remote({
    required String remoteUserId,
    required String username,
    required String role,
    required String tenantId,
  }) {
    return AuthSession(
      userId: 0,
      username: username,
      role: role,
      tenantId: tenantId,
      remoteUserId: remoteUserId,
      isRemote: true,
    );
  }
}
