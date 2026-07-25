import 'backend_api.dart';

class AppSession {
  static AuthSession? current;
  static BackendAppointment? latestAppointment;

  static void set(AuthSession session) {
    current = session;
    latestAppointment = null;
  }

  static void clear() {
    current = null;
    latestAppointment = null;
  }

  static void setLatestAppointment(BackendAppointment appointment) {
    latestAppointment = appointment;
  }

  static String? get patientId {
    final userPatientId = current?.user['patient_id'];
    final profileId = current?.profile?['id'];
    if (userPatientId is String && userPatientId.trim().isNotEmpty) {
      return userPatientId.trim();
    }
    if (current?.user['role'] == 'patient' &&
        profileId is String &&
        profileId.trim().isNotEmpty) {
      return profileId.trim();
    }
    return null;
  }

  static String? get doctorId {
    final userDoctorId = current?.user['doctor_id'];
    final profileId = current?.profile?['id'];
    if (userDoctorId is String && userDoctorId.trim().isNotEmpty) {
      return userDoctorId.trim();
    }
    if (current?.user['role'] == 'doctor' &&
        profileId is String &&
        profileId.trim().isNotEmpty) {
      return profileId.trim();
    }
    return null;
  }

  static String get role {
    final value = current?.user['role'];
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : 'patient';
  }

  static bool get isDoctor => role == 'doctor';

  static bool get isAdmin => role == 'admin';

  static String get fullName {
    final profileName = current?.profile?['full_name'];
    return profileName is String && profileName.trim().isNotEmpty
        ? profileName.trim()
        : 'Noura Al-Amri';
  }

  static String get firstName {
    final parts = fullName.split(RegExp(r'\s+'));
    return parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : fullName;
  }

  static String get email {
    final profileEmail = current?.profile?['email'];
    final userEmail = current?.user['email'];
    if (profileEmail is String && profileEmail.trim().isNotEmpty) {
      return profileEmail.trim();
    }
    if (userEmail is String && userEmail.trim().isNotEmpty) {
      return userEmail.trim();
    }
    return 'noura@example.com';
  }

  static String get mobile {
    final profilePhone = current?.profile?['phone'];
    final userMobile = current?.user['mobile'];
    if (profilePhone is String && profilePhone.trim().isNotEmpty) {
      return profilePhone.trim();
    }
    if (userMobile is String && userMobile.trim().isNotEmpty) {
      return userMobile.trim();
    }
    return '';
  }

  static String get nationalId {
    final profileNationalId = current?.profile?['national_id'];
    final userNationalId = current?.user['national_id'];
    if (profileNationalId is String && profileNationalId.trim().isNotEmpty) {
      return profileNationalId.trim();
    }
    if (userNationalId is String && userNationalId.trim().isNotEmpty) {
      return userNationalId.trim();
    }
    return '';
  }

  static String get gender {
    final value = current?.profile?['gender'];
    return value is String && value.trim().isNotEmpty ? value.trim() : '';
  }

  static String get dateOfBirth {
    final value = current?.profile?['date_of_birth'];
    return value is String && value.trim().isNotEmpty ? value.trim() : '';
  }

  static String get bloodType {
    final value = current?.profile?['blood_type'];
    return value is String && value.trim().isNotEmpty ? value.trim() : '';
  }

  static String get specialty {
    final value = current?.profile?['specialty'];
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : 'General Physician';
  }

  static String get degree {
    final value = current?.profile?['degree'];
    return value is String && value.trim().isNotEmpty ? value.trim() : '';
  }

  static String get initials {
    final words = fullName
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return 'NA';
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }
}
