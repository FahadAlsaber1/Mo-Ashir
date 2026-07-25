import 'package:flutter/material.dart';
import '../data/mock.dart';
import 'vital_signs_checking_screen.dart';

class AppointmentDateTimeScreen extends StatefulWidget {
  const AppointmentDateTimeScreen({super.key, required this.doctor});
  final Doctor doctor;
  @override
  State<AppointmentDateTimeScreen> createState() =>
      _AppointmentDateTimeScreenState();
}

class _AppointmentDateTimeScreenState extends State<AppointmentDateTimeScreen> {
  int selectedDay = 0;
  String selectedTime = '09:00 AM';
  final days = const [
    ('Tue', '14', 'Jul'),
    ('Wed', '15', 'Jul'),
    ('Thu', '16', 'Jul'),
    ('Fri', '17', 'Jul'),
    ('Sat', '18', 'Jul'),
    ('Sun', '19', 'Jul')
  ];
  final times = const [
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '04:00 PM',
    '04:30 PM',
    '05:00 PM',
    '05:30 PM'
  ];
  final booked = const {'10:00 AM', '11:30 AM'};

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Doctors'), backgroundColor: Colors.transparent),
        body: SafeArea(
            top: false,
            child: Column(children: [
              Expanded(
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                      children: [
                    Text('Book with ${widget.doctor.name}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 7),
                    const Text(
                        'Working: Sun · Mon · Tue · Wed · Thu · 09:00 AM–05:00 PM',
                        style: TextStyle(color: Colors.black54, height: 1.4)),
                    const SizedBox(height: 14),
                    _FeeBanner(doctor: widget.doctor),
                    const SizedBox(height: 28),
                    const Text('Select Day',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    SizedBox(
                        height: 94,
                        child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: days.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final selected = i == selectedDay;
                              final d = days[i];
                              return InkWell(
                                  onTap: () => setState(() => selectedDay = i),
                                  borderRadius: BorderRadius.circular(18),
                                  child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      width: 72,
                                      decoration: BoxDecoration(
                                          color:
                                              selected ? primary : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                              color: selected
                                                  ? primary
                                                  : Colors.black12)),
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(d.$1,
                                                style: TextStyle(
                                                    color: selected
                                                        ? Colors.white70
                                                        : Colors.black54)),
                                            Text(d.$2,
                                                style: TextStyle(
                                                    color: selected
                                                        ? Colors.white
                                                        : Colors.black,
                                                    fontSize: 23,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            Text(d.$3,
                                                style: TextStyle(
                                                    color: selected
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                    fontSize: 12))
                                          ])));
                            })),
                    const SizedBox(height: 28),
                    const Text('Select Time',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                        'Slots already booked with this doctor are disabled.',
                        style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 14),
                    GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: times.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10),
                        itemBuilder: (_, i) {
                          final time = times[i];
                          final disabled = booked.contains(time);
                          final selected = selectedTime == time;
                          return OutlinedButton(
                              onPressed: disabled
                                  ? null
                                  : () => setState(() => selectedTime = time),
                              style: OutlinedButton.styleFrom(
                                  backgroundColor: selected ? primary : null,
                                  foregroundColor:
                                      selected ? Colors.white : Colors.black87,
                                  side: BorderSide(
                                      color:
                                          selected ? primary : Colors.black12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16))),
                              child: Text(time,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)));
                        }),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => VitalSignsCheckingScreen(
                                      doctor: widget.doctor,
                                      appointment:
                                          '${days[selectedDay].$1} ${days[selectedDay].$2} ${days[selectedDay].$3} · $selectedTime'))),
                          style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28))),
                          child: const Text('Continue to checking vital signs',
                              style: TextStyle(fontWeight: FontWeight.w800))))),
            ])));
  }
}

class _FeeBanner extends StatelessWidget {
  const _FeeBanner({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0ECE5)),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Consultation fee',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          Text(doctor.consultationFeeLabel,
              style: TextStyle(color: primary, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
