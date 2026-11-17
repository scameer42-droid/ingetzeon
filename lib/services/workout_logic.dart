import 'dart:math' as math;

import 'workout_data.dart';

export 'workout_data.dart';

/// Logika olahraga — sinkron dengan versi web (website/index.html, bagian OLAHRAGA).
const secPerRep = 3;

Exercise exerciseById(String id) => exercises.firstWhere((e) => e.id == id);
WorkoutProgram? programById(String id) {
  for (final p in workoutPrograms) {
    if (p.id == id) return p;
  }
  return null;
}

class WorkoutStep {
  const WorkoutStep(this.ex, this.amount, this.secs, this.round);
  final Exercise ex;
  final int amount, secs, round;
}

class Workout {
  /// Urutan gerakan (istirahat disisipkan oleh pemutar).
  static List<WorkoutStep> steps(WorkoutProgram p, {double mult = 1}) => [
        for (var r = 1; r <= p.rounds; r++)
          for (final (id, amt) in p.items)
            () {
              final ex = exerciseById(id);
              final a = math.max(1, ((amt > 0 ? amt : ex.amount) * mult).round());
              return WorkoutStep(ex, a, ex.timed ? a : a * secPerRep, r);
            }(),
      ];

  static int seconds(WorkoutProgram p, {double mult = 1}) {
    final s = steps(p, mult: mult);
    return s.fold(0, (a, x) => a + x.secs) + math.max(0, s.length - 1) * p.rest;
  }

  /// Kalori = MET × berat(kg) × jam.
  static double burn(double met, double? kg, int secs) => met * (kg ?? 65) * secs / 3600;

  static double kcal(WorkoutProgram p, double? kg, {double mult = 1}) => steps(p, mult: mult).fold(0.0, (a, x) => a + burn(x.ex.met, kg, x.secs));

  static String amountText(Exercise ex, int a) => ex.timed ? (a >= 60 && a % 60 == 0 ? '${a ~/ 60} menit' : '$a detik') : '$a×';

  /// "tadi jogging 30 menit", "renang 1 jam" → aktivitas bebas.
  static ({String name, double met, int minutes})? parseActivity(String text) {
    final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (t.contains('?') || RegExp(r'\b(ingatkan|ingetin|ingatin|alarm|nanti|besok|mau|pengen|ingin|rencana)\b').hasMatch(t)) return null;
    double? min;
    RegExpMatch? m;
    if ((m = RegExp(r'(\d+(?:[.,]\d+)?)\s*(menit|mnt|min)\b').firstMatch(t)) != null) {
      min = double.parse(m![1]!.replaceAll(',', '.'));
    } else if ((m = RegExp(r'(\d+(?:[.,]\d+)?)\s*jam\b').firstMatch(t)) != null) {
      min = double.parse(m![1]!.replaceAll(',', '.')) * 60;
    } else if (RegExp(r'\bsetengah jam\b').hasMatch(t)) {
      min = 30;
    } else if (RegExp(r'\bsejam\b|\bsatu jam\b').hasMatch(t)) {
      min = 60;
    }
    if (min == null || min <= 0 || min > 600) return null;
    final acts = [...freeActivities]..sort((a, b) => b.$1.map((k) => k.length).reduce(math.max).compareTo(a.$1.map((k) => k.length).reduce(math.max)));
    for (final (keys, name, met) in acts) {
      for (final k in keys) {
        if (RegExp('(^|[^a-z])${RegExp.escape(k)}(\$|[^a-z])').hasMatch(t)) return (name: name, met: met, minutes: min.round());
      }
    }
    return null;
  }

  /// Pertanyaan/ajakan olahraga → id program yang cocok, 'hub', atau null.
  static String? ask(String text) {
    final t = text.toLowerCase();
    if (!RegExp(r'\b(olahraga|olah raga|latihan|workout|senam|gerakan|kecilin|kecilkan|mengecilkan|mengencangkan|six ?pack|sixpack|peregangan|stretching|kardio|cardio|push ?up|sit ?up|plank|squat|yoga|pemanasan|hiit)\b')
        .hasMatch(t)) {
      return null;
    }
    if (RegExp(r'\b(lansia|orang tua|manula|kakek|nenek|kursi)\b').hasMatch(t)) return 'lansia';
    if (RegExp(r'\b(tanpa lompat|gak lompat|ga lompat|tidak lompat|ramah lutut|lutut sakit)\b').hasMatch(t)) return 'low_impact';
    if (RegExp(r'sakit pinggang|pinggang sakit|sakit punggung|punggung sakit').hasMatch(t)) return 'punggung';
    if (RegExp(r'\b(perut|buncit|begah|sixpack|six pack|six-pack|core|pinggang|lemak perut)\b').hasMatch(t)) {
      if (RegExp(r'pinggang|samping|ramping').hasMatch(t)) return 'pinggang';
      if (RegExp(r'berdiri|tanpa rebahan|gemuk|obesitas').hasMatch(t)) return 'perut_berdiri';
      return RegExp(r'lanjut|berat|six ?-?pack').hasMatch(t)
          ? 'perut_lanjut'
          : RegExp(r'menengah|sedang').hasMatch(t)
              ? 'perut_menengah'
              : 'perut_pemula';
    }
    if (RegExp(r'(7|tujuh) ?menit|\bhiit\b').hasMatch(t)) return 'hiit7';
    if (RegExp(r'\b(kardio|cardio|bakar lemak|bakar kalori)\b').hasMatch(t)) return 'kardio';
    if (RegExp(r'\byoga\b').hasMatch(t)) return 'yoga';
    if (RegExp(r'\bpemanasan\b').hasMatch(t)) return 'pemanasan';
    if (RegExp(r'\b(punggung|postur|bungkuk|pinggang sakit|sakit pinggang)\b').hasMatch(t)) return 'punggung';
    if (RegExp(r'\b(bokong|pantat)\b').hasMatch(t)) return 'bokong';
    if (RegExp(r'\b(kaki|paha|betis)\b').hasMatch(t)) return 'kaki';
    if (RegExp(r'\b(dada|bahu)\b').hasMatch(t)) return RegExp(r'lanjut|berat').hasMatch(t) ? 'atas_lanjut' : 'dada_bahu';
    if (RegExp(r'\b(lengan|tangan|push ?up)\b').hasMatch(t)) return 'lengan';
    if (RegExp(r'\b(peregangan|stretching|lentur|pegal|kaku)\b').hasMatch(t)) return RegExp(r'malam|tidur').hasMatch(t) ? 'stretch_malam' : 'stretch_pagi';
    if (RegExp(r'\b(full ?body|seluruh badan|semua badan)\b').hasMatch(t)) return 'fullbody';
    return 'hub';
  }

  /// Program yang disarankan sesuai profil & jam (maks 4).
  static List<String> recommend({double? kg, double? cm, int? age, String? goal, int weekMinutes = 0, int hour = 12}) {
    final r = <String>[];
    void add(String id) {
      if (!r.contains(id)) r.add(id);
    }

    final bmi = kg != null && cm != null && cm > 0 ? kg / ((cm / 100) * (cm / 100)) : null;
    if (age != null && age >= 60) {
      add('lansia');
      add('punggung');
      add('yoga');
    }
    if (bmi != null && bmi > 27) {
      add('low_impact');
      add('perut_berdiri');
    }
    if (goal == 'turun') {
      if (weekMinutes >= 90 && (bmi == null || bmi <= 27)) {
        add('hiit7');
        add('kardio');
      } else {
        add('low_impact');
        add('perut_pemula');
      }
    }
    if (goal == 'naik') {
      add('fullbody');
      add('dada_bahu');
    }
    if (hour < 9) {
      add('stretch_pagi');
    } else if (hour >= 20) {
      add('stretch_malam');
    }
    add('perut_pemula');
    add('fullbody');
    add('punggung');
    return r.take(4).toList();
  }
}
