import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../services/note_parser.dart';
import 'settings_provider.dart';

/// Satu catatan. Isi catatan rahasia (password/PIN) TIDAK disimpan di sini,
/// melainkan di penyimpanan terenkripsi Android (Keystore).
class Note implements NoteLike {
  const Note({required this.id, required this.label, required this.value, required this.secret, required this.createdAt});
  final String id;
  @override
  final String label;
  @override
  final String value; // kosong untuk catatan rahasia
  @override
  final bool secret;
  @override
  final DateTime createdAt;

  String get display => secret ? label : value;

  Map<String, dynamic> toMap() => {'id': id, 'l': label, 'v': secret ? '' : value, 's': secret, 'c': createdAt.millisecondsSinceEpoch};
  static Note? fromMap(Map m) {
    final id = m['id']?.toString();
    if (id == null) return null;
    return Note(
      id: id,
      label: (m['l'] ?? '').toString(),
      value: (m['v'] ?? '').toString(),
      secret: m['s'] == true,
      createdAt: DateTime.fromMillisecondsSinceEpoch((m['c'] as num?)?.toInt() ?? 0),
    );
  }
}

class NotesNotifier extends Notifier<List<Note>> {
  static const _secure = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final _auth = LocalAuthentication();

  @override
  List<Note> build() {
    final raw = ref.read(settingsRepositoryProvider).get<List>('notes', const []);
    return raw.whereType<Map>().map(Note.fromMap).whereType<Note>().toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _persist() => ref.read(settingsRepositoryProvider).set('notes', state.map((n) => n.toMap()).toList());

  Note? byId(String id) {
    for (final n in state) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Simpan catatan baru. Catatan rahasia dengan judul sama (mis. "password fb") diperbarui.
  Future<Note> add(NoteDraft d) async {
    final now = DateTime.now();
    var list = [...state];
    String id = 'n${now.microsecondsSinceEpoch}';
    if (d.secret) {
      final key = (NoteParser.tokens(d.label)..sort()).join(' ');
      final old = list.where((n) => n.secret && (NoteParser.tokens(n.label)..sort()).join(' ') == key).toList();
      if (old.isNotEmpty) {
        id = old.first.id;
        list = list.where((n) => n.id != id).toList();
      }
      await _secure.write(key: 'note_$id', value: d.value);
    }
    final n = Note(id: id, label: d.secret ? d.label : d.text, value: d.secret ? '' : d.text, secret: d.secret, createdAt: now);
    state = [n, ...list];
    await _persist();
    return n;
  }

  Future<void> edit(Note n, {required String label, String? secretValue}) async {
    final upd = Note(id: n.id, label: label, value: n.secret ? '' : label, secret: n.secret, createdAt: n.createdAt);
    if (n.secret && secretValue != null) await _secure.write(key: 'note_${n.id}', value: secretValue);
    state = [for (final x in state) x.id == n.id ? upd : x];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _persist();
    try {
      await _secure.delete(key: 'note_$id');
    } catch (_) {}
  }

  Future<void> clearAll() async {
    for (final n in state.where((n) => n.secret)) {
      try {
        await _secure.delete(key: 'note_${n.id}');
      } catch (_) {}
    }
    state = [];
    await _persist();
  }

  /// Verifikasi sidik jari / wajah / PIN layar HP. Bila HP tidak punya kunci layar, langsung diizinkan.
  Future<bool> unlock() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return true;
      return await _auth.authenticate(localizedReason: 'Buka catatan rahasia IngetZeon');
    } on PlatformException {
      return false;
    }
  }

  /// Isi catatan rahasia setelah verifikasi; null bila batal/gagal.
  Future<String?> reveal(Note n, {bool skipAuth = false}) async {
    if (!n.secret) return n.value;
    if (!skipAuth && !await unlock()) return null;
    return _secure.read(key: 'note_${n.id}');
  }
}

final notesProvider = NotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);
