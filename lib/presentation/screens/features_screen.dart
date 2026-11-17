import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/reminder.dart';
import '../../providers/chat_provider.dart';
import '../../providers/reminder_provider.dart';
import '../widgets/common.dart';
import 'calm/calm_screen.dart';
import 'calm/calm_tools.dart';
import 'calm/tests_screen.dart';
import 'calorie/calorie_screen.dart';
import 'calorie/weight_screen.dart';
import 'cycle_screen.dart';
import 'home_screen.dart';
import 'muslim/muslim_screen.dart';
import 'muslim/muslim_tools.dart';
import 'notes_screen.dart';
import 'parking_sheet.dart';
import 'reminder_form_screen.dart';
import 'stats_screen.dart';
import 'ticket_screens.dart';
import 'translate_screen.dart';
import 'workout/workout_screen.dart';

typedef _Feat = ({String id, IconData icon, String title, String sub});

/// Semua fitur yang tersedia, dikelompokkan dan bisa dicari.
class FeaturesScreen extends ConsumerStatefulWidget {
  const FeaturesScreen({super.key, required this.onGoTo});
  final void Function(int index) onGoTo;

  @override
  ConsumerState<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends ConsumerState<FeaturesScreen> {
  final _q = TextEditingController();

  static const List<(String, Color, List<_Feat>)> _groups = [
    ('Produktivitas', AppColors.primary, [
      (id: 'new', icon: Icons.add_alarm_rounded, title: 'Pengingat', sub: 'Buat pengingat dengan alarm berlagu'),
      (id: 'notes', icon: Icons.sticky_note_2_outlined, title: 'Catatan & rahasia', sub: 'Simpan catatan, kata sandi terkunci'),
      (id: 'habits', icon: Icons.task_alt_rounded, title: 'Kebiasaan', sub: 'Centang kebiasaan baik tiap hari'),
      (id: 'focus', icon: Icons.timer_outlined, title: 'Fokus', sub: 'Timer fokus & istirahat'),
      (id: 'agenda', icon: Icons.calendar_month_outlined, title: 'Agenda', sub: 'Semua jadwal per tanggal'),
      (id: 'stats', icon: Icons.bar_chart_rounded, title: 'Statistik', sub: 'Progres pengingat 7 hari terakhir'),
    ]),
    ('Aktivitas harian', Color(0xFF0E7490), [
      (id: 'park', icon: Icons.local_parking_rounded, title: 'Lokasi parkir', sub: 'Foto lokasi & pindai tiket parkir'),
      (id: 'ticket', icon: Icons.qr_code_2_rounded, title: 'Tiket parkir', sub: 'Tampilkan tiket parkir yang tersimpan'),
      (id: 'items', icon: Icons.inventory_2_outlined, title: 'Barang', sub: 'Ingat di mana barangmu disimpan'),
      (id: 'trans', icon: Icons.translate_rounded, title: 'Terjemahkan', sub: 'Indonesia ⇄ Inggris, ketik atau ucapkan'),
    ]),
    ('Kesejahteraan', AppColors.success, [
      (id: 'mood', icon: Icons.sentiment_satisfied_alt_rounded, title: 'Cek mood', sub: 'Catat mood & energi hari ini'),
      (id: 'journal', icon: Icons.edit_note_rounded, title: 'Jurnal malam', sub: 'Tulis refleksi sebelum tidur'),
      (id: 'breathe', icon: Icons.air_rounded, title: 'Latihan tenang', sub: 'Latihan napas pelan-pelan'),
      (id: 'support', icon: Icons.chat_bubble_outline_rounded, title: 'Teman cerita', sub: 'Ceritakan perasaanmu ke Asisten'),
      (id: 'tests', icon: Icons.psychology_outlined, title: 'Tes psikologi', sub: 'Kenali kondisi dirimu'),
      (id: 'calm', icon: Icons.spa_outlined, title: 'Ruang Tenang', sub: 'Mood, kebiasaan, fokus, jurnal'),
    ]),
    ('Kesehatan', AppColors.warning, [
      (id: 'ola', icon: Icons.directions_run_rounded, title: 'Olahraga', sub: 'Program latihan & catatan aktivitas'),
      (id: 'kal', icon: Icons.restaurant_rounded, title: 'Kalori & diet', sub: 'Hitung kalori makanan'),
      (id: 'weight', icon: Icons.monitor_weight_outlined, title: 'Berat badan', sub: 'Catat berat & target'),
      (id: 'cycle', icon: Icons.water_drop_outlined, title: 'Siklus haid', sub: 'Pengingat & perkiraan haid'),
    ]),
    ('Ibadah', Color(0xFF0F766E), [
      (id: 'muslim', icon: Icons.mosque_outlined, title: 'Jadwal sholat', sub: 'Waktu sholat & adzan di kotamu'),
      (id: 'qibla', icon: Icons.explore_outlined, title: 'Arah kiblat', sub: 'Kompas arah kiblat'),
      (id: 'quran', icon: Icons.menu_book_outlined, title: "Al-Qur'an", sub: 'Baca surah & ayat'),
      (id: 'doa', icon: Icons.volunteer_activism_outlined, title: 'Doa harian', sub: 'Kumpulan doa sehari-hari'),
      (id: 'tasbih', icon: Icons.touch_app_outlined, title: 'Tasbih', sub: 'Penghitung dzikir'),
    ]),
  ];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  void _open(String id, Reminder? parking) {
    switch (id) {
      case 'new':
        _push(const ReminderFormScreen());
      case 'notes':
        _push(const NotesScreen());
      case 'habits':
        _push(const HabitsScreen());
      case 'focus':
        _push(const FocusScreen());
      case 'agenda':
        widget.onGoTo(1);
      case 'stats':
        _push(Scaffold(appBar: AppBar(), body: const StatsScreen()));
      case 'park':
        startParkingFlow(context, ref);
      case 'ticket':
        if (parking != null) openTicket(context, parking);
      case 'items':
        showItemsSheet(context);
      case 'trans':
        openTranslate(context);
      case 'mood':
        showMoodCheckin(context, ref);
      case 'journal':
        _push(const JournalScreen());
      case 'breathe':
        _push(const BreatheScreen());
      case 'support':
        ref.read(chatProvider.notifier).startSupport();
        ref.read(openChatRequestProvider.notifier).state++;
      case 'tests':
        _push(const TestsScreen());
      case 'calm':
        _push(const CalmScreen());
      case 'ola':
        _push(const WorkoutScreen());
      case 'kal':
        _push(const CalorieScreen());
      case 'weight':
        openWeightScreen(context);
      case 'cycle':
        _push(const CycleScreen());
      case 'muslim':
        _push(const MuslimScreen());
      case 'qibla':
        _push(const QiblaScreen());
      case 'quran':
        _push(const QuranListScreen());
      case 'doa':
        _push(const DoaScreen());
      case 'tasbih':
        _push(const TasbihScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final parking = activeParking(ref.watch(remindersProvider));
    final q = _q.text.trim().toLowerCase();
    bool match(_Feat f) =>
        q.isEmpty ||
        f.title.toLowerCase().contains(q) ||
        f.sub.toLowerCase().contains(q) ||
        tr(f.title).toLowerCase().contains(q) ||
        tr(f.sub).toLowerCase().contains(q);

    final sections = <Widget>[];
    for (final (name, color, items) in _groups) {
      final list = items.where((f) => (f.id != 'ticket' || (parking != null && parking.hasTicket)) && match(f)).toList();
      if (list.isEmpty) continue;
      sections.addAll([
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.muted)),
        ),
        ListGroup(children: [
          for (final f in list) AppListRow(icon: f.icon, title: f.title, subtitle: f.sub, color: color, onTap: () => _open(f.id, parking)),
        ]),
      ]);
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text('Semua fitur', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.4, color: context.ink)),
          const SizedBox(height: 16),
          TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: tr('Cari fitur…'),
              prefixIcon: Icon(Icons.search_rounded, color: context.faint),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr('Hapus pencarian'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_q.clear),
                    ),
            ),
          ),
          ...sections,
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
              child: Text('Fitur "${_q.text.trim()}" tidak ditemukan. Coba kata lain, misalnya "parkir" atau "sholat".',
                  textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 14, height: 1.5)),
            ),
        ],
      ),
    );
  }
}
