import 'package:flutter/material.dart';
import '../data/mock.dart';
import 'hospital_details.dart';

class HospitalsScreen extends StatefulWidget {
  const HospitalsScreen({super.key});
  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  bool listView = true;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(children: [
            const Expanded(
                child: Text('Find Hospitals',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
            TextButton(onPressed: () {}, child: const Text('Pharmacies')),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: TextField(
                    decoration: InputDecoration(
                        hintText: 'Search hospitals',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none)))),
            const SizedBox(width: 10),
            IconButton.filled(
                onPressed: () {},
                icon: const Icon(Icons.tune),
                style: IconButton.styleFrom(minimumSize: const Size(52, 52))),
          ]),
          const SizedBox(height: 18),
          Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: primary.withOpacity(.1),
                  borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                _tab('List', Icons.view_list_outlined, listView,
                    () => setState(() => listView = true)),
                _tab('Nearby Map', Icons.map_outlined, !listView,
                    () => setState(() => listView = false)),
              ])),
          const SizedBox(height: 18),
          if (!listView) _mapPlaceholder(primary),
          if (listView)
            ...hospitals.map((h) => _hospitalCard(context, h, primary)),
        ]);
  }

  Widget _tab(String text, IconData icon, bool selected, VoidCallback tap) =>
      Expanded(
          child: InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18),
                        const SizedBox(width: 7),
                        Text(text,
                            style: const TextStyle(fontWeight: FontWeight.w700))
                      ]))));

  Widget _hospitalCard(BuildContext context, Hospital h, Color primary) => Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => HospitalDetailsScreen(hospital: h))),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Hero(
                    tag: 'hospital-${h.id}',
                    child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              primary.withOpacity(.18),
                              primary.withOpacity(.05)
                            ]),
                            borderRadius: BorderRadius.circular(18)),
                        child: Icon(Icons.local_hospital_outlined,
                            color: primary, size: 38))),
                const SizedBox(width: 13),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(h.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(h.distance,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 17),
                        Text(' ${h.rating}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 9),
                        Flexible(
                            child: Text('${h.doctors} doctors',
                                style: TextStyle(
                                    color: primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)))
                      ])
                    ])),
                const Icon(Icons.chevron_right_rounded, color: Colors.black38),
              ]))));

  Widget _mapPlaceholder(Color primary) => Container(
      height: 360,
      decoration: BoxDecoration(
          color: const Color(0xFFE3F1E8),
          borderRadius: BorderRadius.circular(24)),
      child: Stack(children: [
        const Center(
            child: Icon(Icons.map_outlined, size: 96, color: Colors.white)),
        ...[
          const Alignment(-.5, -.4),
          const Alignment(.5, .2),
          const Alignment(-.1, .6)
        ].map((a) => Align(
            alignment: a,
            child: Icon(Icons.location_on, color: primary, size: 36)))
      ]));
}
