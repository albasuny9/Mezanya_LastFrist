import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Screen-open investigation — Measurement only. No behavior changes.
// Separate from txn_timing.dart (which times the SAVE pipeline). This times
// the OPEN pipeline: AddTransactionScreen -> TransactionEntryForm -> first
// frame. Remove this file and its imports once the investigation is done.
// ═══════════════════════════════════════════════════════════════════════════

class _OpenTimingEntry {
  const _OpenTimingEntry(this.label, this.ms);
  final String label;
  final int ms;
}

/// Singleton accumulator for one "open the add-transaction screen" cycle.
///
/// Usage:
///   1. Call [ScreenOpenTimingCollector.start] as early as possible — at the
///      top of AddTransactionScreen.build().
///   2. Call [ScreenOpenTimingCollector.current.record] at each
///      instrumentation point.
///   3. Call [ScreenOpenTimingCollector.current.printReportAfterFirstFrame]
///      once, from the first build() of TransactionEntryForm — it schedules
///      the print for right after the first frame is actually on screen
///      (the true "time to interactive" moment), and sorts slowest→fastest.
class ScreenOpenTimingCollector {
  ScreenOpenTimingCollector._();

  static ScreenOpenTimingCollector _instance = ScreenOpenTimingCollector._();
  static ScreenOpenTimingCollector get current => _instance;

  static void start() {
    _instance = ScreenOpenTimingCollector._();
    _instance._wall.start();
  }

  final Stopwatch _wall = Stopwatch();
  final List<_OpenTimingEntry> _entries = [];
  bool _printed = false;

  void record(String label, int ms) {
    _entries.add(_OpenTimingEntry(label, ms));
  }

  /// Schedules the report to print right after the current frame is
  /// rendered (WidgetsBinding.addPostFrameCallback), so the reported
  /// "TOTAL" includes everything up to the first frame actually being
  /// visible on screen — not just our synchronous code.
  void printReportAfterFirstFrame() {
    if (!kDebugMode) return;
    if (_printed) return; // only the very first build of the screen
    _printed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wall.stop();
      final totalMs = _wall.elapsedMilliseconds;

      final sorted = [..._entries]..sort((a, b) => b.ms.compareTo(a.ms));

      final buf = StringBuffer();
      buf.writeln('');
      buf.writeln(
          '╔══════════════════════════════════════════════════════════════════╗');
      buf.writeln(
          '║   ADD-TRANSACTION SCREEN OPEN — TIMING REPORT (slowest first)     ║');
      buf.writeln(
          '╠══════════════════════════════════════════════════════════════════╣');

      for (final e in sorted) {
        final bar = '█' * (e.ms ~/ 2).clamp(0, 30);
        final lbl = e.label.padRight(42);
        final ms = e.ms.toString().padLeft(5);
        buf.writeln('║  $lbl $ms ms  $bar');
      }

      buf.writeln(
          '╠══════════════════════════════════════════════════════════════════╣');
      final totalStr = totalMs.toString().padLeft(5);
      buf.writeln(
          '║  TOTAL  tap "Add" → first frame visible          $totalStr ms');
      buf.writeln(
          '╚══════════════════════════════════════════════════════════════════╝');
      debugPrint(buf.toString());
    });
  }
}
