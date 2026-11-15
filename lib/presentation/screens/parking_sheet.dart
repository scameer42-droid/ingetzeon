import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../../services/photo_service.dart';
import '../widgets/common.dart';
import '../widgets/photo_view.dart';
import 'ticket_screens.dart';

/// Alur cepat "Catat parkir": scan tiket / foto lokasi → isi lokasi → (opsional) alarm.
Future<void> startParkingFlow(BuildContext context, WidgetRef ref) async {
  // langsung buka kamera & scan tiket otomatis; bila dibatalkan, tetap bisa catat manual
  final ticket = await scanTicket(context);
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => _ParkingForm(ticket: ticket),
  );
}

class _ParkingForm extends ConsumerStatefulWidget {
  const _ParkingForm({this.photo, this.ticket});
  final String? photo;
  final ScannedTicket? ticket;

  @override
  ConsumerState<_ParkingForm> createState() => _ParkingFormState();
}

class _ParkingFormState extends ConsumerState<_ParkingForm> {
  final _loc = TextEditingController();
  late String? _photo = widget.photo;
  bool _remind = false;
  TimeOfDay _time = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 2)));
  bool _saved = false;
  late ScannedTicket? _ticket = widget.ticket;

  static const _quick = ['B1', 'B2', 'B3', 'P1', 'P2', 'P3', 'Lantai dasar', 'Rooftop'];

  @override
  void dispose() {
    if (!_saved && _photo != null) PhotoService.instance.delete(_photo);
    _loc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final loc = _loc.text.trim();
    if (loc.isEmpty && _photo == null && _ticket == null) {
      showToast(context, 'Isi lokasi, scan tiket, atau ambil foto dulu');
      return;
    }
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    if (_remind) {
      at = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
      if (!at.isAfter(now)) at = addDays(at, 1);
    }
    final r = Reminder.create(
      title: loc.isEmpty ? 'Lokasi parkir' : 'Parkir di $loc',
      note: 'Dicatat ${fmtTime(now)}',
      scheduledAt: at,
      category: ReminderCategory.parkir,
      photoPath: _photo,
      alarm: _remind,
      ticketText: _ticket?.text,
      ticketFormat: _ticket?.format,
    );
    _saved = true;
    await ref.read(remindersProvider.notifier).upsert(r);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, _remind ? 'Parkir dicatat. Alarm jam ${fmtTime(at)} 🔔' : (_ticket != null ? 'Parkir & tiket tersimpan ✓' : 'Lokasi parkir dicatat 📸'));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CategoryIcon(ReminderCategory.parkir, size: 44),
              const SizedBox(width: 12),
              const Expanded(child: Text('Catat lokasi parkir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 16),
            if (_ticket != null) ...[
              TicketBox(
                text: _ticket!.text,
                format: _ticket!.format,
                onShow: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TicketViewScreen(title: 'Tiket (belum disimpan)', text: _ticket!.text, format: _ticket!.format))),
              ),
              const SizedBox(height: 12),
            ] else ...[
              SoftButton(
                label: 'Scan tiket (QR / barcode)',
                icon: Icons.qr_code_scanner_rounded,
                onPressed: () async {
                  final t = await scanTicket(context);
                  if (t != null) {
                    setState(() => _ticket = t);
                    if (mounted) showToast(context, 'Tiket tersimpan ✓');
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_photo != null)
              Stack(children: [
                PhotoThumb(_photo!, height: 190),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    onPressed: () async {
                      final p = await PhotoService.instance.pick(camera: true);
                      if (p != null) {
                        await PhotoService.instance.delete(_photo);
                        setState(() => _photo = p);
                      }
                    },
                  ),
                ),
              ])
            else
              SoftButton(
                label: 'Foto lokasi',
                icon: Icons.photo_camera_rounded,
                onPressed: () async {
                  try {
                    final p = await PhotoService.instance.pick(camera: true);
                    if (p != null) setState(() => _photo = p);
                  } catch (_) {
                    if (mounted) showToast(context, 'Kamera tidak bisa dibuka (izin ditolak)');
                  }
                },
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _loc,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'Mis. B2, pilar C5 dekat lift'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in _quick)
                  ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                    side: BorderSide(color: context.line),
                    backgroundColor: context.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onPressed: () {
                      final t = _loc.text.trim();
                      _loc.text = t.isEmpty ? q : '$t, $q';
                      _loc.selection = TextSelection.collapsed(offset: _loc.text.length);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
              title: const Text('Bunyikan alarm', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(_remind ? 'Ingatkan jam ${two(_time.hour)}.${two(_time.minute)} · ketuk untuk ganti' : 'Mis. saat jam pulang',
                  style: TextStyle(fontSize: 12.5, color: context.muted)),
              onFocusChange: null,
            ),
            if (_remind)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text('Ganti jam (${two(_time.hour)}.${two(_time.minute)})'),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _time,
                      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
                    );
                    if (t != null) setState(() => _time = t);
                  },
                ),
              ),
            const SizedBox(height: 12),
            GradientButton(label: 'Simpan', icon: Icons.check_rounded, onPressed: _save),
            const SizedBox(height: 4),
            Center(
              child: Text('Tanya asisten "di mana aku parkir?" kapan saja',
                  style: TextStyle(fontSize: 12, color: context.faint)),
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 0, child: ColoredBox(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
