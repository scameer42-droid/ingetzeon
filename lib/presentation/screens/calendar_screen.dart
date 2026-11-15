import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../widgets/common.dart';
import '../widgets/reminder_tile.dart';
import 'reminder_form_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(remindersProvider);
    final items = occurrencesOn(list, _selected).where((x) => !x.done).toList();
    final today = DateTime.now();
    final rect = BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Atur waktumu', style: TextStyle(fontSize: 13, color: context.muted, fontWeight: FontWeight.w500)),
                const Text('Kalender', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ]),
            ),
            SoftCard(
              padding: const EdgeInsets.all(10),
              radius: 14,
              onTap: () => setState(() {
                _focused = today;
                _selected = dateOnly(today);
              }),
              child: const Icon(Icons.today_rounded, size: 22),
            ),
          ]),
          const SizedBox(height: 18),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
            radius: 22,
            child: TableCalendar<Occurrence>(
              locale: 'id_ID',
              firstDay: DateTime(today.year - 2),
              lastDay: DateTime(today.year + 5, 12, 31),
              focusedDay: _focused,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: const {CalendarFormat.month: 'Bulan'},
              selectedDayPredicate: (d) => sameDay(d, _selected),
              eventLoader: (d) => occurrencesOn(list, d),
              onDaySelected: (sel, foc) => setState(() {
                _selected = dateOnly(sel);
                _focused = foc;
              }),
              onPageChanged: (foc) => _focused = foc,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: false,
                titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                leftChevronIcon: _chev(context, Icons.chevron_left_rounded),
                rightChevronIcon: _chev(context, Icons.chevron_right_rounded),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.faint),
                weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.faint),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: true,
                cellMargin: const EdgeInsets.all(4),
                defaultDecoration: rect,
                weekendDecoration: rect,
                outsideDecoration: rect,
                disabledDecoration: rect,
                holidayDecoration: rect,
                todayDecoration: rect.copyWith(border: Border.all(color: AppColors.primary, width: 1.5)),
                todayTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                selectedDecoration: rect.copyWith(color: AppColors.primary),
                selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                defaultTextStyle: const TextStyle(fontWeight: FontWeight.w500),
                weekendTextStyle: const TextStyle(fontWeight: FontWeight.w500),
                outsideTextStyle: TextStyle(color: context.faint.withValues(alpha: .6)),
              ),
              calendarBuilders: CalendarBuilders<Occurrence>(
                markerBuilder: (ctx, day, events) {
                  if (events.isEmpty) return null;
                  final cats = events.map((e) => e.reminder.category).toSet().take(3).toList();
                  final sel = sameDay(day, _selected);
                  return Positioned(
                    bottom: 7,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in cats)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(color: sel ? Colors.white : c.color, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final c in ReminderCategory.values)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(c.label, style: TextStyle(fontSize: 11.5, color: context.muted)),
                ]),
            ],
          ),
          SectionHeader(
            sameDay(_selected, today) ? 'Hari ini' : fmtDateShort(_selected),
            action: '+ Tambah',
            onAction: _add,
          ),
          if (items.isEmpty)
            EmptyState(title: 'Tidak ada jadwal', subtitle: fmtDateLong(_selected), actionLabel: 'Tambah di tanggal ini', onAction: _add)
          else
            ...items.map((x) => ReminderTile(x)),
        ],
      ),
    );
  }

  void _add() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReminderFormScreen(initialDate: _selected)));

  Widget _chev(BuildContext context, IconData icon) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: context.card2, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 22, color: context.ink),
      );
}
