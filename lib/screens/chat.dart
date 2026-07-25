import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../services/app_session.dart';
import '../services/backend_api.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialDoctor});

  final Doctor? initialDoctor;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  Doctor? _selectedDoctor;
  Future<List<BackendMessage>>? _messagesFuture;

  @override
  void initState() {
    super.initState();
    _selectedDoctor = widget.initialDoctor;
    if (_selectedDoctor != null) {
      _messagesFuture = _loadMessages(_selectedDoctor!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<BackendMessage>> _loadMessages(Doctor doctor) async {
    final patientId = AppSession.patientId;
    if (patientId == null) return const [];
    return BackendApi.listMessages(patientId: patientId, doctorId: doctor.id);
  }

  Future<void> _send() async {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    final selectedDoctor = _selectedDoctor;
    if (selectedDoctor == null) return;
    final patientId = AppSession.patientId;
    if (patientId == null) return;

    _controller.clear();
    try {
      await BackendApi.sendMessage(
        patientId: patientId,
        doctorId: selectedDoctor.id,
        senderRole: 'patient',
        body: t,
      );
      if (!mounted) return;
      setState(() => _messagesFuture = _loadMessages(selectedDoctor));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send message.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDoctor = _selectedDoctor;

    if (selectedDoctor == null) {
      return _DoctorChatPicker(
        onSelected: (doctor) => setState(() {
          _selectedDoctor = doctor;
          _messagesFuture = _loadMessages(doctor);
        }),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: primary.withValues(alpha: 0.15),
                child: Icon(Icons.person, color: primary)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(selectedDoctor.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Online',
                      style: TextStyle(color: Colors.green, fontSize: 12))
                ])),
            IconButton(
              onPressed: () => setState(() => _selectedDoctor = null),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              tooltip: 'Choose doctor',
              color: primary,
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<BackendMessage>>(
            future: _messagesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data ?? const <BackendMessage>[];
              final displayMessages = messages.isEmpty
                  ? const [
                      BackendMessage(
                        id: 'welcome',
                        senderRole: 'doctor',
                        body: 'Hello! How can I help you today?',
                        createdAt: '',
                      )
                    ]
                  : messages;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: displayMessages.length,
                itemBuilder: (_, i) {
                  final message = displayMessages[i];
                  final mine = message.mineForPatient;
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: mine ? primary : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(message.body,
                          style: TextStyle(
                              color: mine ? Colors.white : Colors.black87)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: const Color(0xFFF1F3F2),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
                backgroundColor: primary,
                child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _send)),
          ]),
        ),
      ],
    );
  }
}

class _DoctorChatPicker extends StatelessWidget {
  const _DoctorChatPicker({required this.onSelected});

  final ValueChanged<Doctor> onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return FutureBuilder<List<BackendDoctor>>(
      future: BackendApi.listDoctors(),
      builder: (context, snapshot) {
        final backendDoctors = snapshot.data ?? const <BackendDoctor>[];
        final source = backendDoctors.isEmpty
            ? doctors
            : backendDoctors
                .map((doctor) => Doctor(
                      doctor.id,
                      doctor.fullName,
                      doctor.specialty,
                      doctor.degree,
                      doctor.rating,
                      doctor.yearsExperience,
                      clinicOverride: doctor.clinicName,
                      languagesOverride: doctor.languages.isEmpty
                          ? null
                          : doctor.languages.join(', '),
                      cityOverride: 'Riyadh',
                      consultationFeeSar:
                          consultationFeeForSpecialty(doctor.specialty),
                    ))
                .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const Text('Choose a doctor',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Select who you want to message.',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 18),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search doctors',
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
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            for (final doctor in source)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: () => onSelected(doctor),
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: primary.withValues(alpha: 0.15),
                            child: Icon(Icons.person, color: primary, size: 30),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doctor.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  doctor.specialty,
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text('Online',
                                    style: TextStyle(
                                        color: Colors.green, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Colors.black38),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
