/// Which emergency roles the profile screens may offer.
///
/// Mirrors the backend rules (backend/app/core/roles.py) for display only: the
/// backend authorises every role change and rejects organisational roles that an
/// administrator has not granted. `admin` is never a profile role.
class ProfileRoles {
  ProfileRoles._();

  static const String fallback = 'citizen';

  /// Always selectable by any user.
  static const List<String> selfSelectable = ['citizen', 'volunteer'];

  /// Selectable only once an administrator has granted them.
  static const List<String> adminGranted = ['ngo', 'police', 'fire', 'ambulance'];

  static String normalize(String? role) => (role ?? '').trim().toLowerCase();

  /// Self-service roles plus the organisational roles the user has been granted, in
  /// display order. Unknown names and `admin` are never included.
  static List<String> available(Iterable<String> grantedRoles) {
    final granted = grantedRoles.map(normalize).toSet();
    return [...selfSelectable, ...adminGranted.where(granted.contains)];
  }

  /// [role] if it is one of [available], otherwise [fallback].
  static String effective(String? role, List<String> available) {
    final normalized = normalize(role);
    return available.contains(normalized) ? normalized : fallback;
  }
}
