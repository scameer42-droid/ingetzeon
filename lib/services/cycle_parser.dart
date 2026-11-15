/// Mengenali perintah seputar haid di chat, mis. "haid aku mulai hari ini",
/// "udah selesai haidnya", "kapan haid berikutnya?".
enum CycleCmd { start, end, ask }

class CycleIntent {
  const CycleIntent(this.cmd, this.daysAgo);
  final CycleCmd cmd;
  final int daysAgo;
}

class CycleParser {
  static final _topic = RegExp(r'\b(haid\w*|menstruasi\w*|mens|menses|datang bulan|masa subur|ovulasi)\b');

  static CycleIntent? parse(String input) {
    final t = input.toLowerCase();
    if (!_topic.hasMatch(t)) return null;
    final body = t.replaceAll('datang bulan', 'haid datang');
    final isQuestion = RegExp(r'\?|\b(kapan|berapa|perkiraan|prediksi|jadwal|kira|masa subur|ovulasi|telat|terlambat|siklus)\b').hasMatch(body);
    var ago = 0;
    if (RegExp(r'\bkemarin\b|\bkemaren\b').hasMatch(body)) ago = 1;
    if (RegExp(r'\blusa kemarin\b|\b2 hari (lalu|yang lalu|yg lalu)\b').hasMatch(body)) ago = 2;
    final m = RegExp(r'\b(\d{1,2}) hari (lalu|yang lalu|yg lalu)\b').firstMatch(body);
    if (m != null) ago = int.parse(m.group(1)!);
    if (RegExp(r'\b(selesai|berhenti|beres|udahan|sudah habis|udah habis|kelar)\b').hasMatch(body) && !body.contains('kapan')) {
      return CycleIntent(CycleCmd.end, ago);
    }
    if (RegExp(r'\b(mulai|datang|dapet|dapat|keluar|hari pertama|lagi haid|sedang haid|lg haid)\b').hasMatch(body) && !isQuestion) {
      return CycleIntent(CycleCmd.start, ago);
    }
    return const CycleIntent(CycleCmd.ask, 0);
  }
}
