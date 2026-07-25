import 'package:flutter/material.dart';
import '../data/mock.dart';
import 'appointment_datetime.dart';

class QuickQuestionsScreen extends StatefulWidget {
  const QuickQuestionsScreen({super.key, required this.doctor});
  final Doctor doctor;
  @override
  State<QuickQuestionsScreen> createState() => _QuickQuestionsScreenState();
}

class _QuickQuestionsScreenState extends State<QuickQuestionsScreen> {
  String duration = 'A few days', severity = 'Moderate', visited = 'No';
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Doctors'), backgroundColor: Colors.transparent),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Center(
                  child: CircleAvatar(
                      radius: 42,
                      backgroundColor: primary.withOpacity(.12),
                      child: Icon(Icons.person_outline,
                          size: 48, color: primary))),
              const SizedBox(height: 15),
              const Text('Quick questions',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              Text('Before booking with ${widget.doctor.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 18),
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: primary.withOpacity(.1),
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: primary),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text(
                            'Your answers help the doctor prepare for the appointment.',
                            style: TextStyle(fontWeight: FontWeight.w600)))
                  ])),
              const SizedBox(height: 20),
              _field('Reason for visit'),
              _field('Describe your symptoms', lines: 3),
              const Text('How long have you had these symptoms?',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              _choices([
                'Less than a day',
                'A few days',
                '1–2 weeks',
                'More than a month'
              ], duration, (v) => setState(() => duration = v)),
              const SizedBox(height: 16),
              const Text('How severe are your symptoms?',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              _choices(['Mild', 'Moderate', 'Severe'], severity,
                  (v) => setState(() => severity = v)),
              const SizedBox(height: 12),
              _field('Any allergies?'),
              _field('Current medications'),
              const Text('Have you visited this doctor before?',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              _choices(
                  ['Yes', 'No'], visited, (v) => setState(() => visited = v)),
              const SizedBox(height: 24),
              SizedBox(
                  height: 54,
                  child: FilledButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AppointmentDateTimeScreen(
                                  doctor: widget.doctor))),
                      style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28))),
                      child: const Text('Continue to date & time',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
              const SizedBox(height: 10),
              SizedBox(
                  height: 52,
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28))),
                      child: const Text('Change appointment time'))),
            ]));
  }

  Widget _field(String hint, {int lines = 1}) => Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
          maxLines: lines,
          decoration: InputDecoration(
              labelText: hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none))));
  Widget _choices(
          List<String> values, String selected, ValueChanged<String> onPick) =>
      Wrap(
          spacing: 8,
          runSpacing: 7,
          children: values
              .map((v) => ChoiceChip(
                  label: Text(v),
                  selected: selected == v,
                  onSelected: (_) => onPick(v),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                      color: selected == v ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600),
                  showCheckmark: false))
              .toList());
}
