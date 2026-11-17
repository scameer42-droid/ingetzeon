import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../../services/memory_parser.dart';
import '../../services/photo_service.dart';
import '../widgets/common.dart';
import '../widgets/photo_view.dart';

/// "Ingat barang": catat di mana sebuah barang disimpan.
Future<void> startItemFlow(BuildContext context) => showAppSheet(
      context: context,
      scroll: false,
      isScrollControlled: true,
      builder: (c) => const _ItemForm(),
    );

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm();

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  String? _photo;
  bool _saved = false;

  @override
  void dispose() {
    if (!_saved && _photo != null) PhotoService.instance.delete(_photo);
    _name.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final item = _name.text.trim().toLowerCase();
    var place = _place.text.trim().toLowerCase();
    if (item.isEmpty || place.isEmpty) {
      showToast(context, 'Isi nama barang dan tempatnya');
      return;
    }
    if (place.startsWith('ke ')) place = 'di ${place.substring(3)}';
    if (!RegExp(r'^(di|dalam)\b').hasMatch(place)) place = 'di $place';
    final r = Reminder.create(
      title: '${MemoryParser.cap(item)} $place',
      scheduledAt: DateTime.now(),
      category: ReminderCategory.barang,
      alarm: false,
      photoPath: _photo,
      item: item,
      place: place,
    );
    _saved = true;
    await ref.read(remindersProvider.notifier).upsert(r);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, 'Dicatat: ${MemoryParser.cap(item)} $place 📦');
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
              const CategoryIcon(ReminderCategory.barang, size: 44),
              const SizedBox(width: 12),
              const Expanded(child: Text('Ingat barang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 16),
            TextField(controller: _name, autofocus: true, decoration: InputDecoration(labelText: tr('Barang apa?'), hintText: tr('Mis. kunci motor, tas kerja, paspor'))),
            const SizedBox(height: 12),
            TextField(controller: _place, decoration: InputDecoration(labelText: tr('Disimpan di mana?'), hintText: tr('Mis. laci meja kamar'))),
            const SizedBox(height: 12),
            if (_photo != null)
              PhotoThumb(_photo!, height: 170)
            else
              SoftButton(
                label: 'Foto tempatnya (opsional)',
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
            GradientButton(label: 'Simpan', icon: Icons.check_rounded, onPressed: _save),
            const SizedBox(height: 8),
            Center(child: Text('Nanti tanya asisten: "di mana kunci motor saya?"', style: TextStyle(fontSize: 12, color: context.muted))),
          ],
        ),
      ),
    );
  }
}
