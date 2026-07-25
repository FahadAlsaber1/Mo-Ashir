class Doctor {
  final String id, name, specialty, credential;
  final double rating;
  final int years;
  final int consultationFeeSar;
  final String? clinicOverride;
  final String? languagesOverride;
  final String? cityOverride;
  const Doctor(
    this.id,
    this.name,
    this.specialty,
    this.credential,
    this.rating,
    this.years, {
    this.consultationFeeSar = 200,
    this.clinicOverride,
    this.languagesOverride,
    this.cityOverride,
  });

  String get clinic =>
      clinicOverride ??
      switch (id) {
        'ahmed' => 'Care Medical Center',
        'sara' => 'Al Noor Hospital',
        'yusuf' => 'Shifa Clinic',
        _ => 'MO\'ASHIR Family Clinic',
      };

  String get languages =>
      languagesOverride ??
      (id == 'yusuf' ? 'Arabic, English, Urdu' : 'Arabic, English');

  String get nextAvailable => switch (id) {
        'ahmed' => 'Today, 4:00 PM',
        'sara' => 'Tomorrow, 9:30 AM',
        'yusuf' => 'Thu, 11:00 AM',
        _ => 'Sun, 10:00 AM',
      };

  String get city =>
      cityOverride ??
      switch (id) {
        'layla' => 'Jeddah',
        _ => 'Riyadh',
      };

  Hospital? get hospital => hospitalForClinic(clinic);

  String get consultationFeeLabel => '$consultationFeeSar SAR';
}

class Hospital {
  final String id, name, distance, location, phone;
  final double rating;
  final int doctors;
  const Hospital(this.id, this.name, this.distance, this.rating, this.doctors,
      this.location, this.phone);
}

const doctors = <Doctor>[
  Doctor('ahmed', 'Dr. Ahmed Mohamed', 'General Physician', 'MBBS, MD', 4.8, 12,
      consultationFeeSar: 180),
  Doctor('sara', 'Dr. Sara Al-Harbi', 'Cardiologist', 'MBBS, DM Cardio', 4.9, 9,
      consultationFeeSar: 260),
  Doctor('yusuf', 'Dr. Yusuf Karim', 'Dermatologist', 'MBBS, MD Derm', 4.7, 7,
      consultationFeeSar: 220),
  Doctor('layla', 'Dr. Layla Nasser', 'Pediatrician', 'MBBS, MD Peds', 4.9, 11,
      consultationFeeSar: 210),
];

int consultationFeeForSpecialty(String specialty) {
  final normalized = specialty.toLowerCase();
  if (normalized.contains('cardio')) return 260;
  if (normalized.contains('derm')) return 220;
  if (normalized.contains('pediatric')) return 210;
  if (normalized.contains('neuro')) return 280;
  if (normalized.contains('dent')) return 190;
  return 180;
}

const hospitals = <Hospital>[
  Hospital('care', 'Care Medical Center', '1.2 km away', 4.7, 24,
      'King Fahd Road, Riyadh', '+966 11 245 6789'),
  Hospital('noor', 'Al Noor Hospital', '2.4 km away', 4.6, 40,
      'Al Olaya, Riyadh', '+966 11 278 4410'),
  Hospital('shifa', 'Shifa Clinic', '3.1 km away', 4.5, 12, 'Al Malaz, Riyadh',
      '+966 11 230 1155'),
];

Doctor? doctorByName(String name) {
  final normalized = name.trim().toLowerCase();
  for (final doctor in doctors) {
    if (doctor.name.toLowerCase() == normalized) return doctor;
  }
  return null;
}

Hospital? hospitalForClinic(String clinicName) {
  final normalized = clinicName.trim().toLowerCase();
  for (final hospital in hospitals) {
    if (hospital.name.toLowerCase() == normalized) return hospital;
  }
  return null;
}
