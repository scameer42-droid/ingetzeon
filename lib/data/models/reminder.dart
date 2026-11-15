import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';

enum RepeatType {
  once('Sekali'),
  daily('Setiap hari'),
  weekly('Setiap minggu'),
  monthly('Setiap bulan');

  const RepeatType(this.label);
  final String label;

  static RepeatType fromName(String? n) =>
      RepeatType.values.firstWhere((e) => e.name == n, orElse: () => RepeatType.once);
}

enum ReminderCategory {
  kerja('Kerja', Color(0xFF5B54E8), Icons.work_outline_rounded),
  pribadi('Pribadi', Color(0xFFD6336C), Icons.favorite_border_rounded),
  kesehatan('Kesehatan', Color(0xFF12A150), Icons.monitor_heart_outlined),
  edukasi('Edukasi', Color(0xFFD97706), Icons.menu_book_rounded),
  parkir('Parkir', Color(0xFF0891B2), Icons.local_parking_rounded),
  barang('Barang', Color(0xFFB45309), Icons.inventory_2_outlined),
  lainnya('Lainnya', Color(0xFF64748B), Icons.star_border_rounded);

  const ReminderCategory(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;

  Color get soft => color.withValues(alpha: .11);

  static ReminderCategory fromName(String? n) =>
      ReminderCategory.values.firstWhere((e) => e.name == n, orElse: () => ReminderCategory.lainnya);
}

const _unset = Object();

class Reminder {
  const Reminder({
    required this.id,
    required this.notifId,
    required this.title,
    this.note,
    required this.scheduledAt,
    this.repeat = RepeatType.once,
    this.category = ReminderCategory.lainnya,
    this.done = false,
    this.doneDates = const [],
    required this.createdAt,
    this.photoPath,
    this.alarm = true,
    this.ticketText,
    this.ticketFormat,
    this.item,
    this.place,
    this.hourly = false,
  });

  /// Membuat pengingat baru dengan id unik.
  factory Reminder.create({
    required String title,
    String? note,
    required DateTime scheduledAt,
    RepeatType repeat = RepeatType.once,
    ReminderCategory category = ReminderCategory.lainnya,
    String? photoPath,
    bool alarm = true,
    String? ticketText,
    String? ticketFormat,
    String? item,
    String? place,
    bool hourly = false,
  }) {
    final now = DateTime.now();
    return Reminder(
      id: '${now.microsecondsSinceEpoch}',
      notifId: Random().nextInt(0x3FFFFFF0) + 1,
      title: title.trim().isEmpty ? 'Pengingat' : title.trim(),
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      scheduledAt: DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day, scheduledAt.hour, scheduledAt.minute),
      repeat: repeat,
      category: category,
      createdAt: now,
      photoPath: photoPath,
      alarm: alarm,
      ticketText: ticketText,
      ticketFormat: ticketFormat,
      item: item,
      place: place,
      hourly: hourly,
    );
  }

  final String id;
  final int notifId;
  final String title;
  final String? note;
  final DateTime scheduledAt;
  final RepeatType repeat;
  final ReminderCategory category;
  final bool done;
  final List<String> doneDates;
  final DateTime createdAt;

  /// Foto (mis. lokasi parkir) yang disimpan di memori aplikasi.
  final String? photoPath;

  /// false = hanya catatan (tanpa bunyi alarm), mis. catatan parkir tanpa jam.
  final bool alarm;

  /// Isi QR/barcode tiket parkir yang di-scan, dan formatnya (qr_code, code_128, ...).
  final String? ticketText;
  final String? ticketFormat;

  /// Catatan barang: nama barang & tempatnya (mis. 'kunci motor', 'di laci meja').
  final String? item;
  final String? place;

  /// Parkir: kirim pengingat tiap jam.
  final bool hourly;

  bool get hasTicket => ticketText != null && ticketText!.isNotEmpty;

  /// Id notifikasi tunda (selalu berbeda dari id utama).
  int get snoozeNotifId => notifId + 0x40000000;

  Reminder copyWith({
    String? title,
    Object? note = _unset,
    DateTime? scheduledAt,
    RepeatType? repeat,
    ReminderCategory? category,
    bool? done,
    List<String>? doneDates,
    Object? photoPath = _unset,
    bool? alarm,
  }) {
    return Reminder(
      id: id,
      notifId: notifId,
      title: title ?? this.title,
      note: identical(note, _unset) ? this.note : note as String?,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      repeat: repeat ?? this.repeat,
      category: category ?? this.category,
      done: done ?? this.done,
      doneDates: doneDates ?? this.doneDates,
      createdAt: createdAt,
      photoPath: identical(photoPath, _unset) ? this.photoPath : photoPath as String?,
      alarm: alarm ?? this.alarm,
      ticketText: ticketText,
      ticketFormat: ticketFormat,
      item: item,
      place: place,
      hourly: hourly,
    );
  }

  /// Apakah pengingat ini muncul di tanggal [day]?
  bool occursOn(DateTime day) {
    final d = dateOnly(day), s = dateOnly(scheduledAt);
    if (d.isBefore(s)) return false;
    return switch (repeat) {
      RepeatType.daily => true,
      RepeatType.weekly => d.weekday == s.weekday,
      RepeatType.monthly => d.day == s.day,
      RepeatType.once => sameDay(d, s),
    };
  }

  DateTime occurrenceOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, scheduledAt.hour, scheduledAt.minute);

  bool isDoneOn(DateTime day) => repeat == RepeatType.once ? done : doneDates.contains(dayKey(day));

  Reminder withDone(DateTime day, bool value) {
    if (repeat == RepeatType.once) return copyWith(done: value);
    final k = dayKey(day);
    final list = doneDates.where((x) => x != k).toList();
    if (value) list.add(k);
    return copyWith(doneDates: list.length > 400 ? list.sublist(list.length - 400) : list);
  }

  /// Jadwal berikutnya yang belum selesai, mulai dari [from].
  DateTime? nextOccurrence([DateTime? from]) {
    final now = from ?? DateTime.now();
    var d = dateOnly(now.isBefore(scheduledAt) ? scheduledAt : now);
    for (var i = 0; i < 400; i++) {
      if (occursOn(d)) {
        final at = occurrenceOn(d);
        if (!at.isBefore(now) && !isDoneOn(d)) return at;
      }
      if (repeat == RepeatType.once && d.isAfter(scheduledAt)) break;
      d = addDays(d, 1);
    }
    return null;
  }

  String get repeatLabel => switch (repeat) {
        RepeatType.weekly => 'Tiap ${hariList[jsDay(scheduledAt)]}',
        RepeatType.monthly => 'Tiap tgl ${scheduledAt.day}',
        _ => repeat.label,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'notifId': notifId,
        'title': title,
        'note': note,
        'scheduledAt': toLocalIso(scheduledAt),
        'repeat': repeat.name,
        'category': category.name,
        'done': done,
        'doneDates': doneDates,
        'createdAt': createdAt.toIso8601String(),
        'photoPath': photoPath,
        'alarm': alarm,
        'ticketText': ticketText,
        'ticketFormat': ticketFormat,
        'item': item,
        'place': place,
        'hourly': hourly,
      };

  factory Reminder.fromMap(Map<dynamic, dynamic> m) => Reminder(
        id: m['id'].toString(),
        notifId: (m['notifId'] as num?)?.toInt() ?? Random().nextInt(0x3FFFFFF0) + 1,
        title: (m['title'] ?? 'Pengingat').toString(),
        note: m['note']?.toString(),
        scheduledAt: parseLocalIso(m['scheduledAt']?.toString()) ?? DateTime.now(),
        repeat: RepeatType.fromName(m['repeat']?.toString()),
        category: ReminderCategory.fromName(m['category']?.toString()),
        done: m['done'] == true,
        doneDates: ((m['doneDates'] as List?) ?? const []).map((e) => e.toString()).toList(),
        createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
        photoPath: m['photoPath']?.toString(),
        alarm: m['alarm'] != false,
        ticketText: m['ticketText']?.toString(),
        ticketFormat: m['ticketFormat']?.toString(),
        item: m['item']?.toString(),
        place: m['place']?.toString(),
        hourly: m['hourly'] == true,
      );
}

/// Satu kemunculan pengingat pada tanggal tertentu.
class Occurrence {
  const Occurrence(this.reminder, this.at, this.done);
  final Reminder reminder;
  final DateTime at;
  final bool done;
}

List<Occurrence> occurrencesOn(List<Reminder> list, DateTime day) {
  final out = <Occurrence>[
    for (final r in list)
      if (r.occursOn(day)) Occurrence(r, r.occurrenceOn(day), r.isDoneOn(day)),
  ];
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

Occurrence? nextUpcoming(List<Reminder> list, [DateTime? now]) {
  Occurrence? best;
  for (final r in list) {
    if (!r.alarm) continue;
    final at = r.nextOccurrence(now);
    if (at != null && (best == null || at.isBefore(best.at))) best = Occurrence(r, at, false);
  }
  return best;
}

/// Catatan parkir terbaru yang belum diambil (maks. 3 hari terakhir).
Reminder? activeParking(List<Reminder> list, [DateTime? now]) {
  final n = now ?? DateTime.now();
  Reminder? best;
  for (final r in list) {
    if (r.category != ReminderCategory.parkir || r.done) continue;
    if (n.difference(r.createdAt).inDays > 3) continue;
    if (best == null || r.createdAt.isAfter(best.createdAt)) best = r;
  }
  return best;
}

/// Catatan barang yang belum diambil, terbaru dulu.
List<Reminder> activeItems(List<Reminder> list) =>
    list.where((r) => r.category == ReminderCategory.barang && r.item != null && !r.done).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
