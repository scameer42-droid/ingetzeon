import 'package:flutter/material.dart';

/// Penggolongan tekanan darah & gula darah.
///
/// Tekanan darah: klasifikasi yang dipakai Kemenkes RI (PNPK Tata Laksana Hipertensi Dewasa,
/// mengacu klasifikasi Eropa yang dipakai Perhimpunan Dokter Hipertensi Indonesia):
/// optimal <120/<80, normal 120–129/80–84, normal tinggi 130–139/85–89, hipertensi derajat 1
/// 140–159/90–99, derajat 2 160–179/100–109, derajat 3 ≥180/≥110; hipertensi sistolik terisolasi
/// ≥140/<90.
///
/// Gula darah: PNPK Tatalaksana Diabetes Melitus Tipe 2 Dewasa (KMK HK.01.07/MENKES/302/2026):
/// prediabetes puasa 100–125, TTGO 2 jam 140–199, HbA1c 5,7–6,4%; diabetes puasa ≥126,
/// TTGO 2 jam ≥200, sewaktu ≥200, HbA1c ≥6,5%. Hipoglikemia <70 (derajat 1), <54 (derajat 2).
/// Target kendali penyandang diabetes: sebelum makan 80–130, 1–2 jam setelah makan <180, HbA1c <7%.

const kVitalSource = 'Acuan: PNPK Hipertensi Dewasa & PNPK Diabetes Melitus Tipe 2 Dewasa (Kemenkes RI).';

/// Satu golongan hasil: label, warna, saran singkat, dan apakah perlu segera ditangani.
class VitalLevel {
  const VitalLevel(this.key, this.label, this.color, this.advice, {this.urgent = false});
  final String key, label, advice;
  final Color color;
  final bool urgent;
}

const _green = Color(0xFF10B981), _amber = Color(0xFFF59E0B), _orange = Color(0xFFEA580C), _red = Color(0xFFDC2626), _dark = Color(0xFF991B1B), _blue = Color(0xFF2563EB);

// ---------------- tekanan darah ----------------

const bpLevels = <VitalLevel>[
  VitalLevel('optimal', 'Optimal', _green, 'Tekanan darah ideal. Pertahankan pola hidup sehat.'),
  VitalLevel('normal', 'Normal', _green, 'Masih normal. Tetap batasi garam dan rutin bergerak.'),
  VitalLevel('normal_tinggi', 'Normal tinggi', _amber, 'Mendekati hipertensi. Kurangi garam, jaga berat badan, dan cek rutin.'),
  VitalLevel('h1', 'Hipertensi derajat 1', _orange, 'Ukur ulang setelah istirahat 5 menit. Bila tetap tinggi di hari lain, periksa ke puskesmas atau dokter.'),
  VitalLevel('h2', 'Hipertensi derajat 2', _red, 'Tinggi. Periksakan ke dokter untuk penanganan.'),
  VitalLevel('h3', 'Hipertensi derajat 3', _dark,
      'Sangat tinggi. Ukur ulang setelah istirahat. Bila tetap ≥180/110, atau ada nyeri dada, sesak, sakit kepala hebat, atau lemah sebelah badan, segera ke IGD.',
      urgent: true),
];

const bpLow = VitalLevel('rendah', 'Rendah', _blue, 'Di bawah 90/60. Bila pusing, lemas, atau hampir pingsan, duduk/berbaring dan periksakan ke dokter.');

int _sysIdx(int s) => s < 120 ? 0 : s < 130 ? 1 : s < 140 ? 2 : s < 160 ? 3 : s < 180 ? 4 : 5;
int _diaIdx(int d) => d < 80 ? 0 : d < 85 ? 1 : d < 90 ? 2 : d < 100 ? 3 : d < 110 ? 4 : 5;

/// Golongan tekanan darah: diambil yang lebih tinggi antara sistolik dan diastolik.
VitalLevel classifyBp(int sys, int dia) {
  final hi = _sysIdx(sys) > _diaIdx(dia) ? _sysIdx(sys) : _diaIdx(dia);
  if (hi >= 3) return bpLevels[hi];
  if (sys < 90 || dia < 60) return bpLow;
  return bpLevels[hi];
}

/// Hipertensi sistolik terisolasi: sistolik ≥140 dengan diastolik <90.
bool isIsolatedSystolic(int sys, int dia) => sys >= 140 && dia < 90;

/// Batas tiap golongan untuk tabel panduan.
const bpGuide = <(String, String)>[
  ('Optimal', '< 120 dan < 80'),
  ('Normal', '120–129 dan/atau 80–84'),
  ('Normal tinggi', '130–139 dan/atau 85–89'),
  ('Hipertensi derajat 1', '140–159 dan/atau 90–99'),
  ('Hipertensi derajat 2', '160–179 dan/atau 100–109'),
  ('Hipertensi derajat 3', '≥ 180 dan/atau ≥ 110'),
  ('Hipertensi sistolik terisolasi', '≥ 140 dan < 90'),
];

// ---------------- gula darah ----------------

enum GluKind {
  puasa('Puasa', 'Gula darah puasa', 'mg/dL'),
  pp2('2 jam setelah makan', 'Gula darah 2 jam setelah makan', 'mg/dL'),
  sewaktu('Sewaktu', 'Gula darah sewaktu', 'mg/dL'),
  hba1c('HbA1c', 'HbA1c (rata-rata 3 bulan)', '%');

  const GluKind(this.short, this.label, this.unit);
  final String short, label, unit;

  static GluKind from(String? k) => GluKind.values.firstWhere((x) => x.name == k, orElse: () => GluKind.sewaktu);
}

const _hypo2 = VitalLevel('hipo2', 'Sangat rendah (hipoglikemia)', _dark,
    'Di bawah 54 mg/dL. Segera minum atau makan yang manis, lalu cek ulang 15 menit lagi. Bila tidak membaik, mengantuk, atau bingung, segera cari pertolongan medis.',
    urgent: true);
const _hypo = VitalLevel('hipo', 'Rendah (hipoglikemia)', _blue,
    'Di bawah 70 mg/dL. Minum atau makan yang manis, lalu cek ulang 15 menit lagi. Bila tidak membaik, cari pertolongan medis.');
const _normal = VitalLevel('normal', 'Normal', _green, 'Dalam batas normal.');
const _dm = VitalLevel('diabetes', 'Masuk kriteria diabetes', _red,
    'Satu kali hasil belum cukup untuk diagnosis. Periksakan ke dokter untuk tes ulang dengan darah vena di laboratorium.');

/// Golongan gula darah menurut jenis pemeriksaan.
VitalLevel classifyGlu(GluKind k, double v) {
  if (k == GluKind.hba1c) {
    if (v < 5.7) return _normal;
    if (v < 6.5) return const VitalLevel('pre', 'Prediabetes', _amber, 'HbA1c 5,7–6,4%. Perbaiki pola makan, aktif bergerak, dan konsultasi ke dokter.');
    return _dm;
  }
  if (v < 54) return _hypo2;
  if (v < 70) return _hypo;
  switch (k) {
    case GluKind.puasa:
      if (v < 100) return _normal;
      if (v < 126) return const VitalLevel('pre', 'Prediabetes (GDPT)', _amber, 'Gula darah puasa terganggu (100–125). Kurangi gula, aktif bergerak, dan cek ke dokter.');
      return _dm;
    case GluKind.pp2:
      if (v < 140) return _normal;
      if (v < 200) return const VitalLevel('pre', 'Prediabetes (TGT)', _amber, 'Toleransi glukosa terganggu (140–199). Kurangi gula, aktif bergerak, dan cek ke dokter.');
      return _dm;
    case GluKind.sewaktu:
      if (v < 200) return const VitalLevel('normal', 'Di bawah 200', _green, 'Di bawah batas diabetes untuk gula darah sewaktu.');
      return _dm;
    case GluKind.hba1c:
      return _normal;
  }
}

/// Target kendali untuk penyandang diabetes. null = jenis ini tidak punya target harian.
({String text, int status})? diabetesTarget(GluKind k, double v) {
  switch (k) {
    case GluKind.puasa:
      return (text: 'Target sebelum makan 80–130', status: v < 80 ? -1 : (v <= 130 ? 0 : 1));
    case GluKind.pp2:
      return (text: 'Target setelah makan < 180', status: v < 70 ? -1 : (v < 180 ? 0 : 1));
    case GluKind.hba1c:
      return (text: 'Target HbA1c < 7%', status: v < 7 ? 0 : 1);
    case GluKind.sewaktu:
      return null;
  }
}

/// Batas tiap golongan untuk tabel panduan: (pemeriksaan, normal, prediabetes, diabetes).
const gluGuide = <(String, String, String, String)>[
  ('Puasa (≥ 8 jam)', '< 100', '100–125', '≥ 126'),
  ('2 jam setelah TTGO*', '< 140', '140–199', '≥ 200'),
  ('Sewaktu', '< 200', '–', '≥ 200 + gejala'),
  ('HbA1c', '< 5,7%', '5,7–6,4%', '≥ 6,5%'),
];
