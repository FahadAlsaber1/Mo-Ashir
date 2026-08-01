import 'dart:convert';

import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  BackendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.profile,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic>? profile;
}

class BackendDoctor {
  const BackendDoctor({
    required this.id,
    required this.fullName,
    required this.specialty,
    required this.degree,
    required this.rating,
    required this.yearsExperience,
    required this.clinicName,
    required this.isOnline,
    required this.workingStart,
    required this.workingEnd,
    required this.workingDays,
    required this.languages,
    required this.certificates,
  });

  final String id;
  final String fullName;
  final String specialty;
  final String degree;
  final double rating;
  final int yearsExperience;
  final String clinicName;
  final bool isOnline;
  final String workingStart;
  final String workingEnd;
  final List<String> workingDays;
  final List<String> languages;
  final List<String> certificates;

  factory BackendDoctor.fromJson(Map<String, dynamic> json) {
    return BackendDoctor(
      id: _string(json['id']),
      fullName: _string(json['full_name']),
      specialty: _string(json['specialty']),
      degree: _string(json['degree']),
      rating: _double(json['rating'], fallback: 4.8),
      yearsExperience: _int(json['years_experience']),
      clinicName: _string(json['clinic_name'], fallback: 'Care Medical Center'),
      isOnline: json['is_online'] != false,
      workingStart: _string(json['working_start'], fallback: '09:00 AM'),
      workingEnd: _string(json['working_end'], fallback: '05:00 PM'),
      workingDays: _stringList(json['working_days']),
      languages: _stringList(json['languages']),
      certificates: _stringList(json['certificates']),
    );
  }
}

class BackendPatient {
  const BackendPatient({
    required this.id,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    required this.bloodType,
    required this.email,
    required this.phone,
    required this.nationalId,
  });

  final String id;
  final String fullName;
  final String gender;
  final String dateOfBirth;
  final String bloodType;
  final String email;
  final String phone;
  final String nationalId;

  String get initials {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'PT';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  factory BackendPatient.fromJson(Map<String, dynamic> json) {
    return BackendPatient(
      id: _string(json['id']),
      fullName: _string(json['full_name'], fallback: 'Patient'),
      gender: _string(json['gender']),
      dateOfBirth: _string(json['date_of_birth']),
      bloodType: _string(json['blood_type']),
      email: _string(json['email']),
      phone: _string(json['phone']),
      nationalId: _string(json['national_id']),
    );
  }
}

class BackendAppointment {
  const BackendAppointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorClinicName,
    required this.dateLabel,
    required this.timeLabel,
    required this.reason,
    required this.status,
    required this.visitMode,
    this.ctasLevel,
    this.patient,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String doctorClinicName;
  final String dateLabel;
  final String timeLabel;
  final String reason;
  final String status;
  final String visitMode;
  final int? ctasLevel;
  final Map<String, dynamic>? patient;

  String get displayDate => dateLabel.replaceAll('\n', ', ');

  factory BackendAppointment.fromJson(Map<String, dynamic> json) {
    return BackendAppointment(
      id: _string(json['id']),
      patientId: _string(json['patient_id']),
      doctorId: _string(json['doctor_id']),
      doctorName: _string(json['doctor_name'], fallback: 'Doctor'),
      doctorSpecialty: _string(json['doctor_specialty']),
      doctorClinicName: _string(json['doctor_clinic_name']),
      dateLabel: _string(json['date_label']),
      timeLabel: _string(json['time_label']),
      reason: _string(json['reason']),
      status: _string(json['status']),
      visitMode: _string(json['visit_mode'], fallback: 'in_clinic'),
      ctasLevel: json['ctas_level'] == null ? null : _int(json['ctas_level']),
      patient: json['patient'] is Map<String, dynamic>
          ? json['patient'] as Map<String, dynamic>
          : null,
    );
  }
}

class BackendMedication {
  const BackendMedication({
    required this.id,
    required this.name,
    required this.dose,
    required this.schedule,
    required this.active,
    required this.deliveryStatus,
  });

  final String id;
  final String name;
  final String dose;
  final String schedule;
  final bool active;
  final String deliveryStatus;

  String get statusLabel => active ? 'Active' : 'Inactive';

  String get deliveryStatusLabel {
    return switch (deliveryStatus) {
      'out_for_delivery' => 'Out for delivery',
      'delivered' => 'Delivered',
      'cancelled' => 'Cancelled',
      _ => 'Preparing delivery',
    };
  }

  factory BackendMedication.fromJson(Map<String, dynamic> json) {
    return BackendMedication(
      id: _string(json['id']),
      name: _string(json['name']),
      dose: _string(json['dose']),
      schedule: _string(json['schedule']),
      active: json['active'] != false,
      deliveryStatus:
          _string(json['delivery_status'], fallback: 'preparing_delivery'),
    );
  }
}

class BackendVital {
  const BackendVital({
    required this.id,
    required this.vitalType,
    required this.value,
    required this.source,
    required this.approvalStatus,
    required this.measuredAt,
  });

  final String id;
  final String vitalType;
  final String value;
  final String source;
  final String approvalStatus;
  final String measuredAt;

  factory BackendVital.fromJson(Map<String, dynamic> json) {
    return BackendVital(
      id: _string(json['id']),
      vitalType: _string(json['vital_type']),
      value: _string(json['value']),
      source: _string(json['source']),
      approvalStatus: _string(json['approval_status'], fallback: 'pending'),
      measuredAt: _string(json['measured_at']),
    );
  }
}

class BackendMessage {
  const BackendMessage({
    required this.id,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderRole;
  final String body;
  final String createdAt;

  bool get mineForPatient => senderRole == 'patient';
  bool get mineForDoctor => senderRole == 'doctor';

  factory BackendMessage.fromJson(Map<String, dynamic> json) {
    return BackendMessage(
      id: _string(json['id']),
      senderRole: _string(json['sender_role']),
      body: _string(json['body']),
      createdAt: _string(json['created_at']),
    );
  }
}

class BackendApi {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static Future<AuthSession> registerPatient({
    required String fullName,
    required String nationalId,
    required String mobile,
    required String email,
    required String dateOfBirth,
    required String gender,
    required String password,
  }) async {
    final data = await _post('/api/auth/register', {
      'full_name': fullName,
      'national_id': nationalId,
      'mobile': mobile,
      'email': email,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'password': password,
    });
    return _authSessionFrom(data);
  }

  static Future<AuthSession> registerDoctor({
    required String fullName,
    required String nationalId,
    required String mobile,
    required String email,
    required String specialty,
    required String degree,
    required int yearsExperience,
    required String clinicName,
    required String workingStart,
    required String workingEnd,
    required List<String> workingDays,
    required List<String> languages,
    required List<String> certificates,
    required bool acceptingAppointments,
    required String password,
  }) async {
    final data = await _post('/api/auth/register-doctor', {
      'full_name': fullName,
      'national_id': nationalId,
      'mobile': mobile,
      'email': email,
      'specialty': specialty,
      'degree': degree,
      'years_experience': yearsExperience,
      'clinic_name': clinicName,
      'working_start': workingStart,
      'working_end': workingEnd,
      'working_days': workingDays,
      'languages': languages,
      'certificates': certificates,
      'accepting_appointments': acceptingAppointments,
      'password': password,
    });
    return _authSessionFrom(data);
  }

  static Future<AuthSession> login({
    required String role,
    required String method,
    required String identifier,
    required String password,
  }) async {
    final data = await _post('/api/auth/login', {
      'role': role,
      'method': method,
      'identifier': identifier,
      'password': password,
    });
    return _authSessionFrom(data);
  }

  static Future<List<BackendDoctor>> listDoctors() async {
    final data = await _get('/api/doctors');
    if (data is! Map<String, dynamic> || data['doctors'] is! List) {
      throw BackendApiException('Invalid doctors response.');
    }
    return (data['doctors'] as List)
        .whereType<Map<String, dynamic>>()
        .map(BackendDoctor.fromJson)
        .toList();
  }

  static Future<List<BackendPatient>> listPatients() async {
    final data = await _get('/api/patients');
    if (data is! Map<String, dynamic> || data['patients'] is! List) {
      throw BackendApiException('Invalid patients response.');
    }
    return (data['patients'] as List)
        .whereType<Map<String, dynamic>>()
        .map(BackendPatient.fromJson)
        .toList();
  }

  static Future<BackendAppointment?> getUpcomingAppointment({
    required String patientId,
  }) async {
    final data = await _get('/api/patients/$patientId/appointments/upcoming');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid appointment response.');
    }
    final appointment = data['appointment'];
    if (appointment == null) return null;
    if (appointment is! Map<String, dynamic>) {
      throw BackendApiException('Invalid appointment response.');
    }
    return BackendAppointment.fromJson(appointment);
  }

  static Future<List<BackendAppointment>> listPatientAppointments({
    required String patientId,
  }) async {
    final data = await _get('/api/patients/$patientId/appointments');
    if (data is! Map<String, dynamic> || data['appointments'] is! List) {
      throw BackendApiException('Invalid appointments response.');
    }
    return (data['appointments'] as List)
        .whereType<Map<String, dynamic>>()
        .map(BackendAppointment.fromJson)
        .toList();
  }

  static Future<List<BackendAppointment>> listDoctorAppointments({
    required String doctorId,
  }) async {
    final data = await _get('/api/doctors/$doctorId/appointments');
    if (data is! Map<String, dynamic> || data['appointments'] is! List) {
      throw BackendApiException('Invalid appointments response.');
    }
    return (data['appointments'] as List)
        .whereType<Map<String, dynamic>>()
        .map(BackendAppointment.fromJson)
        .toList();
  }

  static Future<List<BackendMedication>> listMedications({
    required String patientId,
  }) async {
    final data = await _get('/api/patients/$patientId/medications');
    if (data is! Map<String, dynamic> || data['medications'] is! List) {
      throw BackendApiException('Invalid medications response.');
    }
    return (data['medications'] as List)
        .whereType<Map<String, dynamic>>()
        .map(BackendMedication.fromJson)
        .toList();
  }

  static Future<BackendMedication> createMedication({
    required String patientId,
    required String name,
    required String dose,
    required String schedule,
    required bool active,
    String deliveryStatus = 'preparing_delivery',
  }) async {
    final data = await _post('/api/patients/$patientId/medications', {
      'name': name,
      'dose': dose,
      'schedule': schedule,
      'active': active,
      'delivery_status': deliveryStatus,
    });
    if (data is! Map<String, dynamic> ||
        data['medication'] is! Map<String, dynamic>) {
      throw BackendApiException('Invalid medication response.');
    }
    return BackendMedication.fromJson(
        data['medication'] as Map<String, dynamic>);
  }

  static Future<List<BackendVital>> listVitals({
    required String patientId,
  }) async {
    final data = await _get('/api/patients/$patientId/vitals');
    if (data is! Map<String, dynamic> || data['vitals'] is! List) {
      throw BackendApiException('Invalid vitals response.');
    }
    return (data['vitals'] as List)
        .whereType<Map<String, dynamic>>()
        .map(BackendVital.fromJson)
        .toList();
  }

  static Future<List<BackendVital>> createVitals({
    required String patientId,
    required String appointmentId,
    required List<Map<String, String>> vitals,
  }) async {
    final data = await _post('/api/patients/$patientId/vitals', {
      'appointment_id': appointmentId,
      'vitals': vitals,
    });
    if (data is! Map<String, dynamic> || data['vitals'] is! List) {
      throw BackendApiException('Invalid vitals response.');
    }
    return (data['vitals'] as List)
        .whereType<Map<String, dynamic>>()
        .map(BackendVital.fromJson)
        .toList();
  }

  static Future<BackendVital> createFahadTemperature({
    required double temperatureC,
    required DateTime capturedAt,
    String? confidence,
  }) async {
    final data = await _post('/api/demo/fahad-account/temperature', {
      'temperature_c': temperatureC,
      'captured_at': capturedAt.toIso8601String(),
      if (confidence != null && confidence.trim().isNotEmpty)
        'confidence': confidence.trim(),
    });
    if (data is! Map<String, dynamic> ||
        data['vital'] is! Map<String, dynamic>) {
      throw BackendApiException('Invalid vital response.');
    }
    return BackendVital.fromJson(data['vital'] as Map<String, dynamic>);
  }

  static Future<BackendVital> createHospitalStationTemperature({
    required String patientId,
    required String appointmentId,
    required double temperatureC,
    required DateTime capturedAt,
    String? confirmation,
  }) async {
    final data = await _post('/api/hospital-station/temperature', {
      'patient_id': patientId,
      'appointment_id': appointmentId,
      'temperature_c': temperatureC,
      'captured_at': capturedAt.toIso8601String(),
      if (confirmation != null && confirmation.trim().isNotEmpty)
        'confirmation': confirmation.trim(),
    });
    if (data is! Map<String, dynamic> ||
        data['vital'] is! Map<String, dynamic>) {
      throw BackendApiException('Invalid station temperature response.');
    }
    return BackendVital.fromJson(data['vital'] as Map<String, dynamic>);
  }

  static Future<BackendAppointment> createAppointment({
    required String patientId,
    required String doctorName,
    required String dateLabel,
    required String timeLabel,
    required String reason,
    String? notes,
    int? ctasLevel,
  }) async {
    final data = await _post('/api/appointments', {
      'patient_id': patientId,
      'doctor_name': doctorName,
      'date_label': dateLabel,
      'time_label': timeLabel,
      'reason': reason,
      'notes': notes,
      'visit_mode': 'in_clinic',
      'ctas_level': ctasLevel,
    });
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid appointment response.');
    }
    final appointment = data['appointment'];
    if (appointment is! Map<String, dynamic>) {
      throw BackendApiException('Invalid appointment response.');
    }
    return BackendAppointment.fromJson(appointment);
  }

  static Future<BackendAppointment> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    final data = await _patch('/api/appointments/$appointmentId/status', {
      'status': status,
    });
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid appointment response.');
    }
    final appointment = data['appointment'];
    if (appointment is! Map<String, dynamic>) {
      throw BackendApiException('Invalid appointment response.');
    }
    return BackendAppointment.fromJson(appointment);
  }

  static Future<BackendVital> updateVitalApproval({
    required String vitalId,
    required String approvalStatus,
  }) async {
    final data = await _patch('/api/vitals/$vitalId/approval', {
      'approval_status': approvalStatus,
    });
    if (data is! Map<String, dynamic> ||
        data['vital'] is! Map<String, dynamic>) {
      throw BackendApiException('Invalid vital response.');
    }
    return BackendVital.fromJson(data['vital'] as Map<String, dynamic>);
  }

  static Future<List<BackendMessage>> listMessages({
    required String patientId,
    required String doctorId,
  }) async {
    final data =
        await _get('/api/messages?patient_id=$patientId&doctor_id=$doctorId');
    if (data is! Map<String, dynamic> || data['messages'] is! List) {
      throw BackendApiException('Invalid messages response.');
    }
    return (data['messages'] as List)
        .whereType<Map<String, dynamic>>()
        .map(BackendMessage.fromJson)
        .toList();
  }

  static Future<BackendMessage> sendMessage({
    required String patientId,
    required String doctorId,
    required String senderRole,
    required String body,
  }) async {
    final data = await _post('/api/messages', {
      'patient_id': patientId,
      'doctor_id': doctorId,
      'sender_role': senderRole,
      'body': body,
    });
    if (data is! Map<String, dynamic> ||
        data['message'] is! Map<String, dynamic>) {
      throw BackendApiException('Invalid message response.');
    }
    return BackendMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw BackendApiException(
        detail is String ? detail : 'Request failed. Please try again.',
      );
    }

    return decoded;
  }

  static Future<dynamic> _get(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw BackendApiException(
        detail is String ? detail : 'Request failed. Please try again.',
      );
    }
    return decoded;
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw BackendApiException(
        detail is String ? detail : 'Request failed. Please try again.',
      );
    }

    return decoded;
  }

  static AuthSession _authSessionFrom(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid server response.');
    }
    final user = data['user'];
    final profile = data['profile'];
    if (user is! Map<String, dynamic>) {
      throw BackendApiException('Invalid user response.');
    }
    return AuthSession(
      user: user,
      profile: profile is Map<String, dynamic> ? profile : null,
    );
  }
}

String _string(dynamic value, {String fallback = ''}) {
  return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? fallback;
}

double _double(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => '$item')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}
