import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../../services/natural_parser.dart';
import '../../services/photo_service.dart';
import '../widgets/common.dart';
import '../widgets/photo_view.dart';

/// Tambah / ubah pengingat secara manual.
class ReminderFormScreen extends ConsumerStatefulWidget {
  const ReminderFormScreen({super.key, this.existing, this.initialDate});
  final Reminder? existing;
  final DateTime? initialDate;

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date;
  late TimeOfDay _time;
  late RepeatType _repeat;
  late ReminderCategory _category;
  bool _categoryTouched = false;
  String? _photo;
  bool _alarm = true;
  bool _saved = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _title = TextEditingController(text: r?.title ?? '');
    _note = TextEditingController(text: r?.note ?? '');
    _repeat = r?.repeat ?? RepeatType.once;
    _category = r?.category ?? ReminderCategory.pribadi;
    _categoryTouched = r != null;
    _photo = r?.photoPath;
    _alarm = r?.alarm ?? true;

    DateTime d;
    if (r != null) {
      d = r.scheduledAt;
    } else {
      final now = DateTime.now();
      final init = widget.initialDate;
      if (init == null || sameDay(init, now)) {
        final x = now.add(const Duration(hours: 1));
        d = DateTime(x.year, x.month, x.day, x.hour);
      } else {
        d = DateTime(init.year, init.month, init.day, 9);
      }
    }
    _date = dateOnly(d);
    _time = TimeOfDay(hour: d.hour, minute: d.minute);

    _title.addListener(() {
      if (_categoryTouched) return;
      final g = NaturalParser.guessCategory(_title.text);
      if (g != null && g != _category) setState(() => _category = g);
    });
  }

  @override
  void dispose() {
    // foto baru yang tidak jadi disimpan dihapus
    if (!_saved && _photo != null && _photo != widget.existing?.photoPath) PhotoService.instance.delete(_photo);
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      locale: const Locale('id', 'ID'),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showToast(context, 'Judul belum diisi');
      return;
    }
    final at = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (_alarm && _repeat == RepeatType.once && at.isBefore(DateTime.now()) && !_editing) {
      showToast(context, 'Waktunya sudah lewat, pilih jam lain');
      return;
    }
    final notifier = ref.read(remindersProvider.notifier);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    _saved = true;
    if (_editing) {
      final old = widget.existing!;
      await notifier.edit(old, old.copyWith(title: title, note: note, scheduledAt: at, repeat: _repeat, category: _category, photoPath: _photo, alarm: _alarm));
      if (mounted) showToast(context, 'Pengingat diperbarui');
    } else {
      await notifier.upsert(Reminder.create(title: title, note: note, scheduledAt: at, repeat: _repeat, category: _category, photoPath: _photo, alarm: _alarm));
      if (mounted) showToast(context, 'Pengingat disimpan ✓');
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final r = widget.existing!;
    final ok = await confirmDialog(context, title: 'Hapus pengingat?', message: '"${r.title}" akan dihapus.', ok: 'Hapus', danger: true);
    if (!ok) return;
    await ref.read(remindersProvider.notifier).remove(r.id);
    if (mounted) {
      showToast(context, 'Pengingat dihapus');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Ubah pengingat' : 'Pengingat baru'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _label('Judul'),
            TextField(
              controller: _title,
              autofocus: !_editing,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr('Mis. Minum obat'), counterText: ''),
            ),
            const SizedBox(height: 16),
            _label('Catatan (opsional)'),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr('Detail tambahan…'), counterText: ''),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Tanggal'),
                  _PickerBox(icon: Icons.calendar_today_rounded, text: fmtDateShort(_date), onTap: _pickDate),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Jam'),
                  _PickerBox(icon: Icons.schedule_rounded, text: '${two(_time.hour)}.${two(_time.minute)}', onTap: _pickTime),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            _label('Ulangi'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in RepeatType.values)
                  _Choice(
                    label: r.label,
                    icon: r == RepeatType.once ? Icons.schedule_rounded : Icons.repeat_rounded,
                    selected: _repeat == r,
                    color: AppColors.primary,
                    onTap: () => setState(() => _repeat = r),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label('Kategori'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ReminderCategory.values)
                  _Choice(
                    label: c.label,
                    icon: c.icon,
                    selected: _category == c,
                    color: c.color,
                    onTap: () => setState(() {
                      _category = c;
                      _categoryTouched = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label('Foto (opsional)'),
            if (_photo != null)
              Stack(children: [
                PhotoThumb(_photo!, height: 180),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () {
                      if (_photo != widget.existing?.photoPath) PhotoService.instance.delete(_photo);
                      setState(() => _photo = null);
                    },
                  ),
                ),
              ])
            else
              Row(children: [
                Expanded(child: SoftButton(label: 'Kamera', icon: Icons.photo_camera_rounded, onPressed: () => _pickPhoto(true))),
                const SizedBox(width: 10),
                Expanded(child: SoftButton(label: 'Galeri', icon: Icons.photo_library_rounded, onPressed: () => _pickPhoto(false))),
              ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 2),
              value: _alarm,
              onChanged: (v) => setState(() => _alarm = v),
              title: const Text('Bunyikan alarm', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(_alarm ? 'Alarm berbunyi seperti lagu sampai kamu matikan' : 'Hanya catatan, tanpa bunyi',
                  style: TextStyle(fontSize: 12.5, color: context.muted)),
            ),
            const SizedBox(height: 16),
            GradientButton(label: 'Simpan pengingat', icon: Icons.check_rounded, onPressed: _save),
            if (_editing) ...[
              const SizedBox(height: 10),
              SoftButton(label: 'Hapus', icon: Icons.delete_outline_rounded, color: AppColors.pink, onPressed: _delete),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(bool camera) async {
    try {
      final p = await PhotoService.instance.pick(camera: camera);
      if (p != null) setState(() => _photo = p);
    } catch (_) {
      showToast(context, camera ? 'Kamera tidak bisa dibuka' : 'Galeri tidak bisa dibuka');
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.muted)),
      );
}

class _PickerBox extends StatelessWidget {
  const _PickerBox({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.line, width: 1.5),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
        ]),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.icon, required this.selected, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? color : context.card,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? Colors.transparent : context.line, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : context.muted),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: selected ? Colors.white : context.muted)),
        ]),
      ),
    );
  }
}
