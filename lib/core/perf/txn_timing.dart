import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Sprint #2 — Measurement only. No behavior changes.
// Remove this file and every import of it once the sprint is complete.
// ═══════════════════════════════════════════════════════════════════════════

class _TxnTimingEntry {
  const _TxnTimingEntry(this.label, this.ms);
  final String label;
  final int ms;
}

/// Singleton accumulator for one transaction save cycle.
///
/// Usage:
///   1. Call [TxnTimingCollector.startSave] at the moment the user taps Save.
///   2. Call [TxnTimingCollector.current.record] at each instrumentation point.
///   3. Call [TxnTimingCollector.current.printSyncReport] after emit() returns
///      (UI is responsive again).
///   4. Background tasks call [TxnTimingCollector.printBackground] whenever
///      they finish — these lines appear in the console after the sync report.
class TxnTimingCollector {
  TxnTimingCollector._();

  static TxnTimingCollector _instance = TxnTimingCollector._();

  /// The active collector for the current transaction.
  static TxnTimingCollector get current => _instance;

  /// Reset and start a fresh measurement cycle.
  /// Call this at the very start of each Save press.
  static void startSave() {
    _instance = TxnTimingCollector._();
    _instance._saveWall.start();
  }

  final Stopwatch _saveWall = Stopwatch();
  final List<_TxnTimingEntry> _entries = [];

  /// Record a named timing measurement in milliseconds.
  void record(String label, int ms) {
    _entries.add(_TxnTimingEntry(label, ms));
  }

  /// Print the synchronous-pipeline portion of the report.
  /// Call this immediately after [emit(next)] returns so "TOTAL" reflects
  /// the true time the UI was blocked.
  void printSyncReport() {
    if (!kDebugMode) return;
    _saveWall.stop();
    final totalMs = _saveWall.elapsedMilliseconds;

    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln(
        '╔══════════════════════════════════════════════════════════════════╗');
    buf.writeln(
        '║        TRANSACTION PIPELINE — TIMING REPORT (sync)              ║');
    buf.writeln(
        '╠══════════════════════════════════════════════════════════════════╣');

    for (final e in _entries) {
      final bar = '█' * (e.ms ~/ 5).clamp(0, 22);
      final lbl = e.label.padRight(42);
      final ms = e.ms.toString().padLeft(5);
      buf.writeln('║  $lbl $ms ms  $bar');
    }

    buf.writeln(
        '╠══════════════════════════════════════════════════════════════════╣');
    final totalStr = totalMs.toString().padLeft(5);
    buf.writeln(
        '║  TOTAL  Save → UI responsive                    $totalStr ms');
    buf.writeln(
        '╠══════════════════════════════════════════════════════════════════╣');
    buf.writeln(
        '║  Background tasks below (reported when each finishes)           ║');
    buf.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');
    debugPrint(buf.toString());
  }

  /// Print a single background-task timing line.
  /// Call this from inside fire-and-forget async tasks (backup, sync, etc.)
  /// after they complete.
  static void printBackground(String label, int ms) {
    if (!kDebugMode) return;
    final bar = '█' * (ms ~/ 50).clamp(0, 22);
    final lbl = label.padRight(42);
    final msStr = ms.toString().padLeft(6);
    debugPrint('  ║ [BG]  $lbl $msStr ms  $bar');
  }
}
