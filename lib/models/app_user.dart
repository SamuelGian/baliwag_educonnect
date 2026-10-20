enum UserRole { student, admin, provider }

UserRole userRoleFromName(String? name) =>
    UserRole.values.firstWhere((r) => r.name == name, orElse: () => UserRole.student);

/// Only meaningful when [AppUser.role] is [UserRole.provider] — gates
/// whether a provider account may actually sign in to [ProviderShell] (see
/// AuthGate) or sits on a "waiting for approval" screen instead. Every
/// provider starts [pending]; only an Admin can move it to [approved] or
/// [rejected] (see the "Providers" tab on the Admin Dashboard).
enum ProviderStatus { pending, approved, rejected }

ProviderStatus providerStatusFromName(String? name) => ProviderStatus.values
    .firstWhere((s) => s.name == name, orElse: () => ProviderStatus.pending);

class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final String studentNumber;
  final String course;

  /// Reusable applicant details, filled in once via Profile Settings and
  /// auto-fillable into every future scholarship application. Deliberately
  /// excludes things that vary per application (household income, GWA).
  final String contactNumber;
  final String address;
  final String guardianName;

  /// The scholarship-granting organization's display name — only set (and
  /// only meaningful) for [UserRole.provider] accounts. Stamped onto every
  /// scholarship a provider creates (see AppState.createScholarship) instead
  /// of the freeform text field Admin uses.
  final String organizationName;

  /// Only meaningful for [UserRole.provider] — see [ProviderStatus].
  final ProviderStatus providerStatus;

  const AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.studentNumber = '',
    this.course = '',
    this.contactNumber = '',
    this.address = '',
    this.guardianName = '',
    this.organizationName = '',
    this.providerStatus = ProviderStatus.pending,
  });

  /// Whether there's anything saved worth offering to auto-fill.
  bool get hasProfileDetails =>
      course.isNotEmpty || contactNumber.isNotEmpty || address.isNotEmpty || guardianName.isNotEmpty;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      role: userRoleFromName(data['role'] as String?),
      studentNumber: data['studentNumber'] as String? ?? '',
      course: data['course'] as String? ?? '',
      contactNumber: data['contactNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      guardianName: data['guardianName'] as String? ?? '',
      organizationName: data['organizationName'] as String? ?? '',
      providerStatus: providerStatusFromName(data['providerStatus'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'role': role.name,
      'studentNumber': studentNumber,
      'course': course,
      'contactNumber': contactNumber,
      'address': address,
      'guardianName': guardianName,
      'organizationName': organizationName,
      'providerStatus': providerStatus.name,
    };
  }

  AppUser copyWith({
    String? fullName,
    String? studentNumber,
    String? course,
    String? contactNumber,
    String? address,
    String? guardianName,
    String? organizationName,
    ProviderStatus? providerStatus,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role,
      studentNumber: studentNumber ?? this.studentNumber,
      course: course ?? this.course,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
      guardianName: guardianName ?? this.guardianName,
      organizationName: organizationName ?? this.organizationName,
      providerStatus: providerStatus ?? this.providerStatus,
    );
  }
}
