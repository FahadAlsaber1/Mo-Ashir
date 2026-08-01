import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/backend_api.dart';
import 'profile.dart';

class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _index = 0;

  final _pages = const [
    DoctorHomeScreen(),
    DoctorChatScreen(),
    DoctorProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final _previousSearch = TextEditingController();
  final _patientSearch = TextEditingController();
  late Future<List<BackendAppointment>> _appointmentsFuture;
  List<BackendAppointment> _latestAppointments = const [];

  @override
  void initState() {
    super.initState();
    _appointmentsFuture = _loadAppointments();
  }

  @override
  void dispose() {
    _previousSearch.dispose();
    _patientSearch.dispose();
    super.dispose();
  }

  Future<List<BackendAppointment>> _loadAppointments() {
    final doctorId = AppSession.doctorId;
    if (doctorId == null) return Future.value(const []);
    return BackendApi.listDoctorAppointments(doctorId: doctorId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BackendAppointment>>(
      future: _appointmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            children: const [
              _DoctorHeader(),
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator()),
            ],
          );
        }
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            children: [
              const _DoctorHeader(),
              const SizedBox(height: 24),
              _EmptyDoctorCard(
                message: 'Could not load appointments.',
                actionLabel: 'Retry',
                onTap: () => setState(
                  () => _appointmentsFuture = _loadAppointments(),
                ),
              ),
            ],
          );
        }
        return _buildHome(snapshot.data ?? const []);
      },
    );
  }

  Widget _buildHome(List<BackendAppointment> appointments) {
    _latestAppointments = appointments;
    final previousQuery = _previousSearch.text.toLowerCase();
    final patientQuery = _patientSearch.text.toLowerCase();
    final patients = _patientsFromAppointments(appointments);
    final queue = _queueFromAppointments(appointments);
    final upcomingPatients =
        patients.where((patient) => patient.status == 'Upcoming').toList();
    final previousPatients = patients
        .where((patient) => patient.status == 'Previous')
        .where((patient) =>
            previousQuery.isEmpty ||
            '${patient.name} ${patient.reason}'
                .toLowerCase()
                .contains(previousQuery))
        .toList();
    final filteredPatients = patients
        .where((patient) =>
            patientQuery.isEmpty ||
            '${patient.name} ${patient.reason}'
                .toLowerCase()
                .contains(patientQuery))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      children: [
        const _DoctorHeader(),
        const SizedBox(height: 24),
        _NextPatientCard(
            patient: upcomingPatients.isEmpty ? null : upcomingPatients.first),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DashboardMetric(
                icon: Icons.groups_outlined,
                value: '${upcomingPatients.length}',
                label: 'Upcoming patients',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardMetric(
                icon: Icons.assignment_outlined,
                value: '${patients.length - upcomingPatients.length}',
                label: 'Previous patients',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ManageScheduleCard(onTap: _scrollMessage),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.local_shipping_outlined,
                title: 'Send Medication Delivery Request',
                subtitle: 'After issuing the prescription',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.note_alt_outlined,
                title: 'Issue Medical Leave',
                subtitle: "Sent to the patient's app",
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _QueueManagementCard(
          patients: queue,
          onCallNext: _callNext,
          onStart: _startPatient,
          onComplete: _completePatient,
          onSkip: _skipPatient,
        ),
        const SizedBox(height: 24),
        const Text('Previous patients',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Search past visits by name or reason',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        _SearchField(
          controller: _previousSearch,
          hint: 'Search previous patients...',
          onChanged: (_) => setState(() {}),
        ),
        if (previousQuery.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (previousPatients.isEmpty)
            const _InlineEmptyState('No previous patients found.')
          else
            ...previousPatients
                .map((patient) => _PatientCard(patient: patient)),
        ],
        const SizedBox(height: 24),
        const Text('Patients',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        _SearchField(
          controller: _patientSearch,
          hint: 'Search patients by name or reason...',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (filteredPatients.isEmpty)
          const _InlineEmptyState('No patients yet.')
        else
          ...filteredPatients.map((patient) => _PatientCard(patient: patient)),
      ],
    );
  }

  void _scrollMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Queue management is below.')),
    );
  }

  void _callNext() {
    final queue = _queueFromAppointments(_latestAppointments);
    if (queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No waiting patients.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling ${queue.first.name}.')),
    );
  }

  void _startPatient(_QueuePatient patient) {
    _updateAppointmentStatus(patient, 'in_clinic');
  }

  Future<void> _completePatient(_QueuePatient patient) async {
    final plan = await _showFinishSessionDialog(patient);
    if (plan == null) return;

    try {
      if (plan.prescription != null) {
        await BackendApi.createMedication(
          patientId: patient.patientId,
          name: plan.prescription!.name,
          dose: plan.prescription!.dose,
          schedule: plan.prescription!.schedule,
          active: plan.prescription!.active,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save prescription. Session not closed.')),
      );
      return;
    }

    final completed = await _updateAppointmentStatus(patient, 'completed');
    if (!completed || !plan.followUp.shouldSchedule) return;

    try {
      await BackendApi.createAppointment(
        patientId: patient.patientId,
        doctorName: patient.doctorName,
        dateLabel: plan.followUp.dateLabel,
        timeLabel: plan.followUp.timeLabel,
        reason: plan.followUp.reason,
        notes: 'Follow-up session for ${patient.name}.',
      );
      if (!mounted) return;
      setState(() => _appointmentsFuture = _loadAppointments());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Follow-up scheduled for ${plan.followUp.dateLabel}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Session completed, but follow-up was not saved.')),
      );
    }
  }

  void _skipPatient(_QueuePatient patient) {
    _updateAppointmentStatus(patient, 'cancelled');
  }

  Future<bool> _updateAppointmentStatus(
      _QueuePatient patient, String status) async {
    if (patient.appointmentId.isEmpty) return false;
    try {
      await BackendApi.updateAppointmentStatus(
        appointmentId: patient.appointmentId,
        status: status,
      );
      if (!mounted) return false;
      setState(() => _appointmentsFuture = _loadAppointments());
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update appointment.')),
      );
      return false;
    }
  }

  Future<_FinishSessionPlan?> _showFinishSessionDialog(_QueuePatient patient) {
    return showDialog<_FinishSessionPlan>(
      context: context,
      builder: (_) => _FinishSessionDialog(patientName: patient.name),
    );
  }

  List<_DoctorPatient> _patientsFromAppointments(
      List<BackendAppointment> appointments) {
    return appointments.map(_doctorPatientFromAppointment).toList();
  }

  List<_QueuePatient> _queueFromAppointments(
      List<BackendAppointment> appointments) {
    final active = appointments
        .where(
            (item) => item.status != 'completed' && item.status != 'cancelled')
        .toList();
    return [
      for (var i = 0; i < active.length; i++)
        _queuePatientFromAppointment(active[i], i),
    ];
  }

  _DoctorPatient _doctorPatientFromAppointment(BackendAppointment appointment) {
    final patient = appointment.patient ?? const <String, dynamic>{};
    final name = _patientName(patient);
    final date =
        appointment.displayDate.isEmpty ? 'Scheduled' : appointment.displayDate;
    final time =
        appointment.timeLabel.isEmpty ? '' : ' - ${appointment.timeLabel}';
    return _DoctorPatient(
      patientId: appointment.patientId,
      doctorId: appointment.doctorId,
      appointmentId: appointment.id,
      name: name,
      reason: appointment.reason.isEmpty ? 'Visit' : appointment.reason,
      time: '$date$time',
      status:
          appointment.status == 'completed' || appointment.status == 'cancelled'
              ? 'Previous'
              : 'Upcoming',
      initials: _patientInitials(name),
      gender: _stringValue(patient['gender']),
      dateOfBirth: _stringValue(patient['date_of_birth']),
      bloodType: _stringValue(patient['blood_type']),
    );
  }

  _QueuePatient _queuePatientFromAppointment(
      BackendAppointment appointment, int index) {
    final patient = appointment.patient ?? const <String, dynamic>{};
    final name = _patientName(patient);
    final mode = appointment.visitMode == 'online' ? 'Online' : 'In clinic';
    final visitLabel =
        appointment.visitMode == 'online' ? 'Video visit' : 'Clinic';
    return _QueuePatient(
      appointment.id,
      appointment.patientId,
      appointment.doctorName,
      'A${13 + index}',
      name,
      '$visitLabel - ${appointment.timeLabel}',
      appointment.ctasLevel == null
          ? 'CTAS 5'
          : 'CTAS ${appointment.ctasLevel}',
      mode,
    );
  }

  String _patientName(Map<String, dynamic> patient) {
    return _stringValue(patient['full_name'], fallback: 'Patient');
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  String _patientInitials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'PT';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class DoctorChatScreen extends StatefulWidget {
  const DoctorChatScreen({super.key, this.initialPatient});

  final _DoctorPatient? initialPatient;

  @override
  State<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  final _controller = TextEditingController();
  _DoctorPatient? _selectedPatient;
  late Future<List<_DoctorPatient>> _patientsFuture;
  Future<List<BackendMessage>>? _messagesFuture;

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.initialPatient;
    _patientsFuture = _loadPatients();
    if (_selectedPatient != null) {
      _messagesFuture = _loadMessages(_selectedPatient!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPatient = _selectedPatient;
    if (selectedPatient == null) {
      return FutureBuilder<List<_DoctorPatient>>(
        future: _patientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _EmptyDoctorCard(
              message: 'Could not load patients.',
              actionLabel: 'Retry',
              onTap: () => setState(() => _patientsFuture = _loadPatients()),
            );
          }
          return _PatientChatPicker(
            patients: snapshot.data ?? const [],
            onSelected: (patient) => setState(() {
              _selectedPatient = patient;
              _messagesFuture = _loadMessages(patient);
            }),
          );
        },
      );
    }

    return FutureBuilder<List<BackendMessage>>(
      future: _messagesFuture,
      builder: (context, snapshot) {
        final messages = (snapshot.data ?? const <BackendMessage>[])
            .map((message) =>
                _DoctorMessage(message.body, message.mineForDoctor))
            .toList();
        return _PatientChatView(
          patient: selectedPatient,
          controller: _controller,
          messages: messages,
          loading: snapshot.connectionState == ConnectionState.waiting,
          onBack: () => setState(() => _selectedPatient = null),
          onSend: _send,
        );
      },
    );
  }

  Future<List<_DoctorPatient>> _loadPatients() async {
    final doctorId = AppSession.doctorId;
    if (doctorId == null) return const [];
    final appointments =
        await BackendApi.listDoctorAppointments(doctorId: doctorId);
    final seen = <String>{};
    final patients = <_DoctorPatient>[];
    for (final appointment in appointments) {
      if (appointment.patientId.isEmpty || !seen.add(appointment.patientId)) {
        continue;
      }
      patients.add(_doctorPatientFromAppointment(appointment));
    }
    return patients;
  }

  Future<List<BackendMessage>> _loadMessages(_DoctorPatient patient) {
    final doctorId = AppSession.doctorId;
    if (doctorId == null || patient.patientId.isEmpty) {
      return Future.value(const []);
    }
    return BackendApi.listMessages(
      patientId: patient.patientId,
      doctorId: doctorId,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final selectedPatient = _selectedPatient;
    if (text.isEmpty || selectedPatient == null) return;
    final doctorId = AppSession.doctorId;
    if (doctorId == null || selectedPatient.patientId.isEmpty) return;

    _controller.clear();
    try {
      await BackendApi.sendMessage(
        patientId: selectedPatient.patientId,
        doctorId: doctorId,
        senderRole: 'doctor',
        body: text,
      );
      if (!mounted) return;
      setState(() => _messagesFuture = _loadMessages(selectedPatient));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send message.')),
      );
    }
  }

  _DoctorPatient _doctorPatientFromAppointment(BackendAppointment appointment) {
    final patient = appointment.patient ?? const <String, dynamic>{};
    final name = _stringValue(patient['full_name'], fallback: 'Patient');
    final date =
        appointment.displayDate.isEmpty ? 'Scheduled' : appointment.displayDate;
    final time =
        appointment.timeLabel.isEmpty ? '' : ' - ${appointment.timeLabel}';
    return _DoctorPatient(
      patientId: appointment.patientId,
      doctorId: appointment.doctorId,
      appointmentId: appointment.id,
      name: name,
      reason: appointment.reason.isEmpty ? 'Visit' : appointment.reason,
      time: '$date$time',
      status:
          appointment.status == 'completed' || appointment.status == 'cancelled'
              ? 'Previous'
              : 'Upcoming',
      initials: _patientInitials(name),
      gender: _stringValue(patient['gender']),
      dateOfBirth: _stringValue(patient['date_of_birth']),
      bloodType: _stringValue(patient['blood_type']),
    );
  }

  String _patientInitials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'PT';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }
}

class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}

class _PatientChatPicker extends StatefulWidget {
  const _PatientChatPicker({
    required this.patients,
    required this.onSelected,
  });

  final List<_DoctorPatient> patients;
  final ValueChanged<_DoctorPatient> onSelected;

  @override
  State<_PatientChatPicker> createState() => _PatientChatPickerState();
}

class _PatientChatPickerState extends State<_PatientChatPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final results = widget.patients
        .where((patient) =>
            _query.isEmpty ||
            '${patient.name} ${patient.reason} ${patient.status}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      children: [
        const Text('Choose a patient',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Select who you want to message.',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 18),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search patients',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (results.isEmpty)
          const _InlineEmptyState('No patients available to message.'),
        for (final patient in results)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: () => widget.onSelected(patient),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: primary.withValues(alpha: 0.15),
                        child: Text(
                          patient.initials,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(patient.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(
                              patient.reason,
                              style: TextStyle(
                                color: primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(patient.status,
                                style: const TextStyle(
                                    color: Colors.green, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.black38),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PatientChatView extends StatelessWidget {
  const _PatientChatView({
    required this.patient,
    required this.controller,
    required this.messages,
    required this.loading,
    required this.onBack,
    required this.onSend,
  });

  final _DoctorPatient patient;
  final TextEditingController controller;
  final List<_DoctorMessage> messages;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: primary.withValues(alpha: 0.15),
                child: Text(
                  patient.initials,
                  style: TextStyle(color: primary, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(patient.reason,
                        style: TextStyle(
                            color: primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                tooltip: 'Choose patient',
                color: primary,
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final message = messages[index];
                        return Align(
                          alignment: message.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: message.mine ? primary : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: message.mine
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    filled: true,
                    fillColor: const Color(0xFFF1F3F2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: onSend,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoctorMessage {
  _DoctorMessage(this.text, this.mine);

  final String text;
  final bool mine;
}

class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back,',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                AppSession.fullName,
                style: const TextStyle(
                  color: Color(0xFF007F3D),
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.medical_services_outlined,
                      size: 15, color: Colors.black54),
                  const SizedBox(width: 4),
                  Text(AppSession.specialty,
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 20,
          backgroundColor: primary.withValues(alpha: .12),
          child: Icon(Icons.notifications_none, color: primary),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 20,
          backgroundColor: primary.withValues(alpha: .12),
          child: Text(
            AppSession.initials,
            style: TextStyle(color: primary, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _NextPatientCard extends StatelessWidget {
  const _NextPatientCard({required this.patient});

  final _DoctorPatient? patient;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final nextPatient = patient;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: Colors.white70, size: 16),
              SizedBox(width: 7),
              Text('Next Patient', style: TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            nextPatient?.name ?? 'No upcoming patient',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(nextPatient?.reason ?? 'New bookings will appear here.',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 18),
          Text(nextPatient?.time ?? '',
              style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: nextPatient == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: SafeArea(
                              child: DoctorChatScreen(
                                initialPatient: nextPatient,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: primary,
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Send message'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            backgroundColor: primary.withValues(alpha: .16),
            child: Icon(icon, color: primary),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              Text(label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManageScheduleCard extends StatelessWidget {
  const _ManageScheduleCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: primary,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white24,
                child:
                    Icon(Icons.event_available_outlined, color: Colors.white),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manage schedule',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                    SizedBox(height: 2),
                    Text('Confirm, complete or reschedule appointments',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 136,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: primary.withValues(alpha: .16),
            child: Icon(icon, color: primary),
          ),
          const Spacer(),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ],
      ),
    );
  }
}

class _EmptyDoctorCard extends StatelessWidget {
  const _EmptyDoctorCard({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, color: primary, size: 42),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _QueueManagementCard extends StatelessWidget {
  const _QueueManagementCard({
    required this.patients,
    required this.onCallNext,
    required this.onStart,
    required this.onComplete,
    required this.onSkip,
  });

  final List<_QueuePatient> patients;
  final VoidCallback onCallNext;
  final ValueChanged<_QueuePatient> onStart;
  final ValueChanged<_QueuePatient> onComplete;
  final ValueChanged<_QueuePatient> onSkip;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient Queue Management',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Current queue',
                        style:
                            TextStyle(color: Color(0xFF007F3D), fontSize: 12)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onCallNext,
                icon: const Icon(Icons.phone_in_talk_outlined, size: 16),
                label: const Text('Call Next'),
                style: FilledButton.styleFrom(backgroundColor: primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (patients.isEmpty)
            const _InlineEmptyState('No active queue patients.')
          else
            for (final patient in patients)
              _QueuePatientTile(
                patient: patient,
                onStart: () => onStart(patient),
                onComplete: () => onComplete(patient),
                onSkip: () => onSkip(patient),
              ),
        ],
      ),
    );
  }
}

class _QueuePatientTile extends StatelessWidget {
  const _QueuePatientTile({
    required this.patient,
    required this.onStart,
    required this.onComplete,
    required this.onSkip,
  });

  final _QueuePatient patient;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFD4F5DE),
                child: Text(patient.queueNumber,
                    style:
                        TextStyle(color: primary, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(patient.detail,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
              _PriorityBadge(priority: patient.priority),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SmallQueueButton(
                  label: 'Start',
                  icon: Icons.play_arrow,
                  color: const Color(0xFFD4F5DE),
                  foreground: primary,
                  onTap: onStart),
              const SizedBox(width: 6),
              _SmallQueueButton(
                  label: 'Complete',
                  icon: Icons.check_circle_outline,
                  color: primary,
                  foreground: Colors.white,
                  onTap: onComplete),
              const SizedBox(width: 6),
              _SmallQueueButton(
                  label: 'Skip',
                  icon: Icons.skip_next_outlined,
                  color: Colors.white,
                  foreground: Colors.black54,
                  onTap: onSkip),
              const SizedBox(width: 6),
              Expanded(
                child: _VisitModeBadge(mode: patient.mode),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallQueueButton extends StatelessWidget {
  const _SmallQueueButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final colors = _priorityColors(priority);
    return Container(
      width: 116,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.foreground.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high_rounded, color: colors.foreground, size: 15),
          const SizedBox(width: 4),
          Text(
            priority,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  _PriorityColors _priorityColors(String value) {
    return switch (value) {
      'CTAS 1' => const _PriorityColors(Color(0xFFFFE1E1), Color(0xFFB42318)),
      'CTAS 2' => const _PriorityColors(Color(0xFFFFEDD5), Color(0xFFB45309)),
      'CTAS 3' => const _PriorityColors(Color(0xFFFFF7CC), Color(0xFF8A6D00)),
      'CTAS 4' => const _PriorityColors(Color(0xFFE0F2FE), Color(0xFF0369A1)),
      _ => const _PriorityColors(Color(0xFFE8F8EE), Color(0xFF007F3D)),
    };
  }
}

class _PriorityColors {
  const _PriorityColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

class _VisitModeBadge extends StatelessWidget {
  const _VisitModeBadge({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final online = mode == 'Online';
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: online ? const Color(0xFFE0F2FE) : const Color(0xFFE8F8EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              online ? const Color(0xFF7DD3FC) : primary.withValues(alpha: .35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            online ? Icons.videocam_outlined : Icons.location_on_outlined,
            color: online ? const Color(0xFF0369A1) : primary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              mode,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: online ? const Color(0xFF0369A1) : primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final _DoctorPatient patient;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final upcoming = patient.status == 'Upcoming';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: primary.withValues(alpha: .15),
                child: Text(patient.initials,
                    style:
                        TextStyle(color: primary, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(patient.reason,
                        style: TextStyle(
                            color: primary, fontWeight: FontWeight.w700)),
                    Text(patient.time,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: upcoming
                      ? const Color(0xFFD4F5DE)
                      : const Color(0xFFE9F1EC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(patient.status,
                    style: TextStyle(
                        color: upcoming ? primary : Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _PatientMedicalHistoryScreen(patient: patient),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment_outlined, size: 16),
                  label: const Text('Medical History'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD4F5DE),
                    foregroundColor: primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: SafeArea(
                            child: DoctorChatScreen(initialPatient: patient),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Chat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatientMedicalHistoryScreen extends StatefulWidget {
  const _PatientMedicalHistoryScreen({required this.patient});

  final _DoctorPatient patient;

  @override
  State<_PatientMedicalHistoryScreen> createState() =>
      _PatientMedicalHistoryScreenState();
}

class _PatientMedicalHistoryScreenState
    extends State<_PatientMedicalHistoryScreen> {
  final Map<String, String> _approvalStatus = {};
  bool _savingPrescription = false;
  late Future<List<BackendMedication>> _medicationsFuture;
  late Future<List<BackendVital>> _vitalsFuture;

  @override
  void initState() {
    super.initState();
    _medicationsFuture = _loadMedications();
    _vitalsFuture = _loadVitals();
  }

  Future<List<BackendMedication>> _loadMedications() {
    if (widget.patient.patientId.isEmpty) return Future.value(const []);
    return BackendApi.listMedications(patientId: widget.patient.patientId);
  }

  Future<List<BackendVital>> _loadVitals() {
    if (widget.patient.patientId.isEmpty) return Future.value(const []);
    return BackendApi.listVitals(patientId: widget.patient.patientId);
  }

  Future<void> _showPrescriptionDialog() async {
    if (widget.patient.patientId.isEmpty) return;
    final prescription = await showDialog<_PrescriptionDraft>(
      context: context,
      builder: (context) => const _PrescriptionDialog(),
    );
    if (prescription == null) return;

    setState(() => _savingPrescription = true);
    try {
      await BackendApi.createMedication(
        patientId: widget.patient.patientId,
        name: prescription.name,
        dose: prescription.dose,
        schedule: prescription.schedule,
        active: prescription.active,
      );
      if (!mounted) return;
      setState(() => _medicationsFuture = _loadMedications());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${prescription.name} added to patient.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add prescription.')),
      );
    } finally {
      if (mounted) setState(() => _savingPrescription = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFFEFFFF5),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Medical History',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 18),
            _MedicalPatientHeader(patient: widget.patient),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: SafeArea(
                          child: DoctorChatScreen(
                            initialPatient: widget.patient,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat with patient'),
              ),
            ),
            const SizedBox(height: 24),
            const _HistorySectionTitle(
              icon: Icons.assignment_outlined,
              title: 'Patient-reported history',
            ),
            const SizedBox(height: 12),
            const _WhitePillText(
              "The patient hasn't filled out their medical history yet.",
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<BackendVital>>(
              future: _vitalsFuture,
              builder: (context, snapshot) {
                final vitals = snapshot.data ?? const <BackendVital>[];
                return Row(
                  children: [
                    Expanded(
                      child: _HistoryMetricCard(
                        icon: Icons.water_drop_outlined,
                        label: 'Blood',
                        value: _displayValue(widget.patient.bloodType),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HistoryMetricCard(
                        icon: Icons.height_outlined,
                        label: 'Height',
                        value: _latestVitalValue(vitals, 'height'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HistoryMetricCard(
                        icon: Icons.monitor_weight_outlined,
                        label: 'Weight',
                        value: _latestVitalValue(vitals, 'weight'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const _HistorySectionTitle(
              icon: Icons.warning_amber_outlined,
              title: 'Allergies',
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AlertChip('Penicillin'),
                _AlertChip('Dust'),
              ],
            ),
            const SizedBox(height: 24),
            const _HistorySectionTitle(
              icon: Icons.health_and_safety_outlined,
              title: 'Chronic Conditions',
            ),
            const SizedBox(height: 12),
            const _ConditionTile(label: 'Hypertension', since: 'Since 2022'),
            const _ConditionTile(
                label: 'Seasonal allergies', since: 'Since 2019'),
            const SizedBox(height: 24),
            _HistorySectionTitle(
              icon: Icons.medication_outlined,
              title: 'Current Medications',
              trailing: TextButton.icon(
                onPressed: _savingPrescription ? null : _showPrescriptionDialog,
                icon: _savingPrescription
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Add prescription'),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<BackendMedication>>(
              future: _medicationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final medications =
                    snapshot.data ?? const <BackendMedication>[];
                if (medications.isEmpty) {
                  return const _WhitePillText('No medications recorded.');
                }
                return Column(
                  children: [
                    for (final medication in medications)
                      _MedicationTile(
                        name: medication.name,
                        dose:
                            '${_displayValue(medication.dose)} - ${_displayValue(medication.schedule)}',
                        status: medication.statusLabel,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _HistorySectionTitle(
              icon: Icons.monitor_heart_outlined,
              title: 'Vitals review - doctor approval',
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Approval required',
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Review the latest measurements from camera, app, manual entry, or connected devices. Confirm each vital or request a retake.',
              style:
                  TextStyle(color: Colors.black54, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<BackendVital>>(
              future: _vitalsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final vitals = snapshot.data ?? const <BackendVital>[];
                final cards = _buildVitalCards(vitals);
                if (cards.isEmpty) {
                  return const _WhitePillText('No vitals recorded yet.');
                }
                return Column(children: cards);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildVitalCards(List<BackendVital> vitals) {
    final grouped = <String, List<BackendVital>>{};
    for (final vital in vitals) {
      final key = _normalizeVitalName(vital.vitalType);
      if (key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(vital);
    }

    const preferredOrder = [
      'temperature',
      'height',
      'weight',
      'bloodpressure',
      'heartrate',
      'oxygen',
      'breathingrate',
    ];

    final orderedKeys = [
      for (final key in preferredOrder)
        if (grouped.containsKey(key)) key,
      ...grouped.keys.where((key) => !preferredOrder.contains(key)),
    ];

    return [
      for (final key in orderedKeys)
        _buildVitalCard(
            _displayVitalTitle(key), grouped[key]!.take(1).toList()),
    ];
  }

  Widget _buildVitalCard(String title, List<BackendVital> vitals) {
    final sources = vitals.map(_sourceFromVital).toList();
    return _VitalApprovalCard(
      title: title,
      status: _statusFor(title, vitals),
      sources: sources,
      onApprove: () => _setVitalApproval(title, vitals, 'confirmed'),
      onRemeasure: () => _setVitalApproval(title, vitals, 'retake_requested'),
    );
  }

  _VitalSource _sourceFromVital(BackendVital vital) {
    final source = vital.source.toLowerCase();
    return _VitalSource(
      label: switch (source) {
        'camera' => 'From camera',
        'manual' => 'Manual entry',
        'device' => 'From device',
        _ => 'From app',
      },
      value: _normalizeVitalName(vital.vitalType) == 'temperature'
          ? _displayTemperatureValue(vital.value)
          : _displayValue(vital.value),
      icon: switch (source) {
        'camera' => Icons.photo_camera_outlined,
        'manual' => Icons.edit_note_outlined,
        _ => Icons.monitor_heart_outlined,
      },
    );
  }

  String _latestVitalValue(List<BackendVital> vitals, String type) {
    final normalizedType = _normalizeVitalName(type);
    for (final vital in vitals) {
      if (_normalizeVitalName(vital.vitalType) == normalizedType) {
        return _displayValue(vital.value);
      }
    }
    return 'Not recorded';
  }

  String _statusFor(String vital, List<BackendVital> vitals) {
    final localStatus = _approvalStatus[vital];
    if (localStatus != null) return localStatus;
    if (vitals.isEmpty) return 'Pending';
    return switch (vitals.first.approvalStatus) {
      'confirmed' => 'Confirmed',
      'retake_requested' => 'Retake requested',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };
  }

  Future<void> _setVitalApproval(
    String vital,
    List<BackendVital> vitals,
    String approvalStatus,
  ) async {
    final displayStatus =
        approvalStatus == 'confirmed' ? 'Confirmed' : 'Retake requested';
    if (vitals.isEmpty) {
      setState(() => _approvalStatus[vital] = displayStatus);
      return;
    }
    try {
      await Future.wait(vitals.map((item) {
        return BackendApi.updateVitalApproval(
          vitalId: item.id,
          approvalStatus: approvalStatus,
        );
      }));
      if (!mounted) return;
      setState(() {
        _approvalStatus[vital] = displayStatus;
        _vitalsFuture = _loadVitals();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update vital approval.')),
      );
    }
  }

  String _normalizeVitalName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _displayVitalTitle(String normalized) {
    return switch (normalized) {
      'bloodpressure' => 'Blood Pressure',
      'heartrate' => 'Heart Rate',
      'breathingrate' => 'Breathing Rate',
      'bodytemperature' || 'temperature' => 'Temperature',
      _ => normalized.replaceAllMapped(RegExp(r'(^|[0-9])([a-z])'), (match) {
          final prefix = match.group(1) ?? '';
          final letter = match.group(2) ?? '';
          return '$prefix${letter.toUpperCase()}';
        }).replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) {
          return '${match.group(1)} ${match.group(2)}';
        }),
    };
  }

  String _displayValue(String value) {
    return value.trim().isEmpty ? 'Not recorded' : value.trim();
  }

  String _displayTemperatureValue(String value) {
    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(value);
    if (match == null) return _displayValue(value);
    final temperature = double.tryParse(match.group(0)!);
    if (temperature == null) return _displayValue(value);
    return '${temperature.round()} C';
  }
}

class _MedicalPatientHeader extends StatelessWidget {
  const _MedicalPatientHeader({required this.patient});

  final _DoctorPatient patient;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: primary.withValues(alpha: .15),
            child: Text(
              patient.initials,
              style: TextStyle(color: primary, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(_patientMeta(patient),
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(patient.reason,
                    style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(patient.time,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _patientMeta(_DoctorPatient patient) {
    final pieces = [
      if (patient.dateOfBirth.isNotEmpty) patient.dateOfBirth,
      if (patient.gender.isNotEmpty) patient.gender,
    ];
    return pieces.isEmpty ? 'Patient' : pieces.join(' - ');
  }
}

class _HistorySectionTitle extends StatelessWidget {
  const _HistorySectionTitle({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, color: primary, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _WhitePillText extends StatelessWidget {
  const _WhitePillText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _HistoryMetricCard extends StatelessWidget {
  const _HistoryMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: primary.withValues(alpha: .14),
            child: Icon(icon, color: primary, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDADA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFFB42318), fontWeight: FontWeight.w700)),
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({required this.label, required this.since});

  final String label;
  final String since;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Text(since, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  const _MedicationTile({
    required this.name,
    required this.dose,
    required this.status,
  });

  final String name;
  final String dose;
  final String status;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary.withValues(alpha: .14),
            child: Icon(Icons.medication_outlined, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(dose,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MedicationStatusBadge(status: status),
        ],
      ),
    );
  }
}

class _MedicationStatusBadge extends StatelessWidget {
  const _MedicationStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'Active';
    final color =
        active ? Theme.of(context).colorScheme.primary : Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD4F5DE) : const Color(0xFFE9F1EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _PrescriptionDraft {
  const _PrescriptionDraft({
    required this.name,
    required this.dose,
    required this.schedule,
    required this.active,
  });

  final String name;
  final String dose;
  final String schedule;
  final bool active;
}

class _FinishDialogSectionTitle extends StatelessWidget {
  const _FinishDialogSectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, color: primary, size: 19),
        const SizedBox(width: 7),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _FinishSessionDialog extends StatefulWidget {
  const _FinishSessionDialog({required this.patientName});

  final String patientName;

  @override
  State<_FinishSessionDialog> createState() => _FinishSessionDialogState();
}

class _FinishSessionDialogState extends State<_FinishSessionDialog> {
  final _medicine = TextEditingController();
  final _dose = TextEditingController();
  final _schedule = TextEditingController();
  final _reason = TextEditingController(text: 'Follow-up session');
  bool _addPrescription = true;
  bool _addFollowUp = false;
  bool _submitted = false;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _medicine.dispose();
    _dose.dispose();
    _schedule.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(_selectedDate);
    final timeLabel = _formatTime(_selectedTime);
    final medicineError =
        _submitted && _addPrescription && _medicine.text.trim().isEmpty
            ? 'Medicine name is required'
            : null;
    return AlertDialog(
      icon: const Icon(Icons.check_circle_outline),
      title: Text('Finish ${widget.patientName} session'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add the prescription for this session, then choose whether the patient needs a follow-up.',
            ),
            const SizedBox(height: 16),
            const _FinishDialogSectionTitle(
              icon: Icons.medication_outlined,
              title: 'Prescription',
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _addPrescription,
              onChanged: (value) => setState(() => _addPrescription = value),
              title: const Text('Add medicine to patient'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_addPrescription) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _medicine,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Medicine name',
                  errorText: medicineError,
                  prefixIcon: const Icon(Icons.medication_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dose,
                decoration: const InputDecoration(
                  labelText: 'Dose',
                  hintText: '500 mg',
                  prefixIcon: Icon(Icons.science_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _schedule,
                decoration: const InputDecoration(
                  labelText: 'Schedule',
                  hintText: 'Twice daily after meals',
                  prefixIcon: Icon(Icons.schedule),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const _FinishDialogSectionTitle(
              icon: Icons.event_repeat_outlined,
              title: 'Follow-up',
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _addFollowUp,
              onChanged: (value) => setState(() => _addFollowUp = value),
              title: const Text('Add follow-up session'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_addFollowUp) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Follow-up reason',
                  prefixIcon: Icon(Icons.edit_note_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(dateLabel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(timeLabel),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            setState(() => _submitted = true);
            final medicineName = _medicine.text.trim();
            final reason = _reason.text.trim();
            if (_addPrescription && medicineName.isEmpty) return;
            if (_addFollowUp && reason.isEmpty) return;
            Navigator.of(context).pop(
              _FinishSessionPlan(
                prescription: _addPrescription
                    ? _PrescriptionDraft(
                        name: medicineName,
                        dose: _dose.text.trim(),
                        schedule: _schedule.text.trim(),
                        active: true,
                      )
                    : null,
                followUp: _FollowUpPlan(
                  shouldSchedule: _addFollowUp,
                  dateLabel: dateLabel,
                  timeLabel: timeLabel,
                  reason: _addFollowUp ? reason : 'Completed appointment',
                ),
              ),
            );
          },
          child:
              Text(_addFollowUp ? 'Complete & schedule' : 'Complete session'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedTime = picked);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class _PrescriptionDialog extends StatefulWidget {
  const _PrescriptionDialog();

  @override
  State<_PrescriptionDialog> createState() => _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<_PrescriptionDialog> {
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _schedule = TextEditingController();
  bool _active = true;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _schedule.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nameError = _submitted && _name.text.trim().isEmpty
        ? 'Medication name is required'
        : null;
    return AlertDialog(
      icon: const Icon(Icons.medication_outlined),
      title: const Text('Add prescription'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Medicine name',
                errorText: nameError,
                prefixIcon: const Icon(Icons.medication_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dose,
              decoration: const InputDecoration(
                labelText: 'Dose',
                hintText: '500 mg',
                prefixIcon: Icon(Icons.science_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _schedule,
              decoration: const InputDecoration(
                labelText: 'Schedule',
                hintText: 'Twice daily after meals',
                prefixIcon: Icon(Icons.schedule),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: Text(_active ? 'Active medicine' : 'Inactive medicine'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            setState(() => _submitted = true);
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              _PrescriptionDraft(
                name: name,
                dose: _dose.text.trim(),
                schedule: _schedule.text.trim(),
                active: _active,
              ),
            );
          },
          child: const Text('Add medicine'),
        ),
      ],
    );
  }
}

class _VitalApprovalCard extends StatelessWidget {
  const _VitalApprovalCard({
    required this.title,
    required this.status,
    required this.sources,
    required this.onApprove,
    required this.onRemeasure,
  });

  final String title;
  final String status;
  final List<_VitalSource> sources;
  final VoidCallback onApprove;
  final VoidCallback onRemeasure;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'Confirmed';
    final remeasure = status.startsWith('Retake');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              _ApprovalBadge(
                text: status,
                approved: approved,
                remeasure: remeasure,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < sources.length; i++) ...[
                Expanded(
                  child: _VitalSourceCard(
                    source: sources[i],
                  ),
                ),
                if (i != sources.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Confirm'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: onRemeasure,
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Retake'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VitalSource {
  const _VitalSource({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _VitalSourceCard extends StatelessWidget {
  const _VitalSourceCard({required this.source});

  final _VitalSource source;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F8E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(source.icon, size: 15, color: Colors.black54),
              const SizedBox(width: 4),
              Expanded(
                child: Text(source.label,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(source.value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({
    required this.text,
    required this.approved,
    required this.remeasure,
  });

  final String text;
  final bool approved;
  final bool remeasure;

  @override
  Widget build(BuildContext context) {
    final color = approved
        ? const Color(0xFF007F3D)
        : remeasure
            ? const Color(0xFFB45309)
            : Colors.black54;
    final background = approved
        ? const Color(0xFFD4F5DE)
        : remeasure
            ? const Color(0xFFFFEDD5)
            : const Color(0xFFE9F1EC);
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _QueuePatient {
  _QueuePatient(
    this.appointmentId,
    this.patientId,
    this.doctorName,
    this.queueNumber,
    this.name,
    this.detail,
    this.priority,
    this.mode,
  );

  final String appointmentId;
  final String patientId;
  final String doctorName;
  final String queueNumber;
  final String name;
  final String detail;
  final String priority;
  final String mode;
}

class _FinishSessionPlan {
  const _FinishSessionPlan({
    required this.prescription,
    required this.followUp,
  });

  final _PrescriptionDraft? prescription;
  final _FollowUpPlan followUp;
}

class _FollowUpPlan {
  const _FollowUpPlan({
    required this.shouldSchedule,
    required this.dateLabel,
    required this.timeLabel,
    required this.reason,
  });

  final bool shouldSchedule;
  final String dateLabel;
  final String timeLabel;
  final String reason;
}

class _DoctorPatient {
  const _DoctorPatient({
    this.patientId = '',
    this.doctorId = '',
    this.appointmentId = '',
    required this.name,
    required this.reason,
    required this.time,
    required this.status,
    required this.initials,
    this.gender = '',
    this.dateOfBirth = '',
    this.bloodType = '',
  });

  final String patientId;
  final String doctorId;
  final String appointmentId;
  final String name;
  final String reason;
  final String time;
  final String status;
  final String initials;
  final String gender;
  final String dateOfBirth;
  final String bloodType;
}
