import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';

/// Hasil scan tiket.
class ScannedTicket {
  const ScannedTicket(this.text, this.format);
  final String text;
  final String format; // qr_code, code_128, ...
}

String _formatName(ms.BarcodeFormat f) => switch (f) {
      ms.BarcodeFormat.qrCode => 'qr_code',
      ms.BarcodeFormat.code128 => 'code_128',
      ms.BarcodeFormat.code39 => 'code_39',
      ms.BarcodeFormat.code93 => 'code_93',
      ms.BarcodeFormat.codabar => 'codabar',
      ms.BarcodeFormat.dataMatrix => 'data_matrix',
      ms.BarcodeFormat.ean13 => 'ean_13',
      ms.BarcodeFormat.ean8 => 'ean_8',
      ms.BarcodeFormat.itf => 'itf',
      ms.BarcodeFormat.upcA => 'upc_a',
      ms.BarcodeFormat.upcE => 'upc_e',
      ms.BarcodeFormat.pdf417 => 'pdf417',
      ms.BarcodeFormat.aztec => 'aztec',
      _ => 'qr_code',
    };

String ticketLabel(String? format) => switch (format) {
      'qr_code' || null => 'QR',
      'pdf417' => 'PDF417',
      'data_matrix' => 'Data Matrix',
      'aztec' => 'Aztec',
      _ => 'Barcode',
    };

bw.Barcode _barcodeFor(String? format) => switch (format) {
      'code_128' => bw.Barcode.code128(),
      'code_39' => bw.Barcode.code39(),
      'code_93' => bw.Barcode.code93(),
      'codabar' => bw.Barcode.codabar(),
      'ean_13' => bw.Barcode.ean13(),
      'ean_8' => bw.Barcode.ean8(),
      'itf' => bw.Barcode.itf(),
      'upc_a' => bw.Barcode.upcA(),
      'upc_e' => bw.Barcode.upcE(),
      'pdf417' => bw.Barcode.pdf417(),
      'data_matrix' => bw.Barcode.dataMatrix(),
      'aztec' => bw.Barcode.aztec(),
      _ => bw.Barcode.qrCode(),
    };

bool _isLinear(String? f) => const {'code_128', 'code_39', 'code_93', 'codabar', 'ean_13', 'ean_8', 'itf', 'upc_a', 'upc_e'}.contains(f);

/// Gambar ulang kode tiket. Bila data tidak cocok dengan formatnya, tampil sebagai QR.
class TicketCode extends StatelessWidget {
  const TicketCode({super.key, required this.text, this.format, this.size = 280});
  final String text;
  final String? format;
  final double size;

  @override
  Widget build(BuildContext context) {
    final linear = _isLinear(format);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(size > 100 ? 12 : 3),
      child: bw.BarcodeWidget(
        barcode: _barcodeFor(format),
        data: text,
        width: size,
        height: linear ? size * .45 : size,
        drawText: false,
        color: Colors.black,
        backgroundColor: Colors.white,
        errorBuilder: (c, e) => bw.BarcodeWidget(
          barcode: bw.Barcode.qrCode(),
          data: text,
          width: size,
          height: size,
          color: Colors.black,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}

/// Layar scan QR/barcode tiket. Mengembalikan [ScannedTicket] atau null.
class TicketScannerScreen extends StatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  final _controller = ms.MobileScannerController(detectionSpeed: ms.DetectionSpeed.noDuplicates, facing: ms.CameraFacing.back);
  bool _done = false;
  String _hint = 'Arahkan kamera ke QR / barcode di tiket';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(ms.BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _done = true;
        Navigator.pop(context, ScannedTicket(v, _formatName(b.format)));
        return;
      }
    }
  }

  Future<void> _fromGallery() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final cap = await _controller.analyzeImage(x.path);
    if (!mounted) return;
    if (cap != null && cap.barcodes.isNotEmpty) {
      _finish(cap);
    } else {
      setState(() => _hint = 'Kode tidak terbaca di foto itu. Coba foto yang lebih dekat & terang.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = MediaQuery.of(context).size.width * .72;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        Positioned.fill(
          child: ms.MobileScanner(
            controller: _controller,
            onDetect: _finish,
            errorBuilder: (c, e) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Kamera tidak bisa dibuka. Izinkan akses kamera di Pengaturan, atau pilih foto tiket.',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x73000000), spreadRadius: 2000)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              const Text('Scan tiket parkir', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
                icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                onPressed: () => _controller.toggleTorch(),
              ),
            ]),
          ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _fromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pilih dari foto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

Future<ScannedTicket?> scanTicket(BuildContext context) =>
    Navigator.of(context).push<ScannedTicket>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const TicketScannerScreen()));

/// Tampilan tiket layar penuh (latar putih agar mudah dibaca mesin parkir).
class TicketViewScreen extends StatelessWidget {
  const TicketViewScreen({super.key, required this.title, required this.text, this.format, this.savedAt});
  final String title;
  final String text;
  final String? format;
  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.light),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.inkLight,
          title: const Text('Tiket parkir'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(children: [
                TicketCode(text: text, format: format, size: w - 80 > 340 ? 340 : w - 80),
                const SizedBox(height: 14),
                SelectableText(text.length > 80 ? '${text.substring(0, 80)}…' : text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 15, letterSpacing: .8, color: AppColors.inkLight)),
                const SizedBox(height: 22),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.inkLight)),
                if (savedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${ticketLabel(format)} · disimpan ${dayLabel(savedAt!).toLowerCase()} jam ${fmtTime(savedAt!)}',
                        style: const TextStyle(color: AppColors.mutedLight, fontSize: 13.5)),
                  ),
                if (savedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(99)),
                      child: Text('⏱ Durasi parkir: ${elapsed(savedAt!)}',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.card2Light, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Naikkan kecerahan layar, lalu tunjukkan ke mesin atau petugas parkir.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.mutedLight, fontSize: 13.5)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

void openTicket(BuildContext context, Reminder r) {
  if (!r.hasTicket) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => TicketViewScreen(title: r.title, text: r.ticketText!, format: r.ticketFormat, savedAt: r.createdAt),
  ));
}

/// Kotak kecil berisi pratinjau tiket + tombol Tampilkan.
class TicketBox extends StatelessWidget {
  const TicketBox({super.key, required this.text, this.format, this.onShow});
  final String text;
  final String? format;
  final VoidCallback? onShow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.line)),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 50, height: 50, child: FittedBox(child: TicketCode(text: text, format: format, size: 60)))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tiket ${ticketLabel(format)} tersimpan', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.muted, fontFamily: 'monospace')),
          ]),
        ),
        if (onShow != null)
          TextButton.icon(onPressed: onShow, icon: const Icon(Icons.qr_code_2_rounded, size: 18), label: const Text('Tampilkan')),
      ]),
    );
  }
}
