/// Entité domaine représentant un utilisateur connecté.
class AppUser {
  final String id;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final List<String> roles;

  const AppUser({
    required this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.roles = const [],
  });

  String get displayName =>
      [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ').trim().isNotEmpty
          ? [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ').trim()
          : username;

  bool get isAdmin => roles.contains('ADMIN');
}
