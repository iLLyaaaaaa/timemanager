import 'package:flutter/foundation.dart';

/// Serializes writes and retains the latest snapshot after a failure.
class SnapshotWriter extends ChangeNotifier {
  SnapshotWriter(this.write);

  final Future<void> Function(String)? write;
  String? _pending;
  Future<void>? _task;
  Object? _error;
  bool _disposed = false;

  bool get isSaving => _task != null;
  bool get hasUnsavedChanges => _pending != null || isSaving;
  bool get hasSaveError => _error != null;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void enqueue(String snapshot) {
    if (write == null) return;
    _pending = snapshot;
    _start();
  }

  void _start() {
    if (_task != null || _pending == null) return;
    // Schedule the drain so its completion cannot race assignment of _task.
    _task = Future<void>.microtask(_drain);
    _changed();
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final snapshot = _pending!;
        _pending = null;
        try {
          await write!(snapshot);
          _error = null;
        } catch (error) {
          _error = error;
          if (_pending == null) {
            _pending = snapshot;
            break; // Explicit retry; never spin on an unavailable disk.
          }
        }
      }
    } finally {
      _task = null;
      _changed();
    }
  }

  Future<bool> flush() async {
    while (_task != null) {
      await _task;
    }
    return _error == null && _pending == null;
  }

  Future<bool> retry() {
    _start();
    return flush();
  }

  void acceptPersisted() {
    if (isSaving) throw StateError('A write is still running');
    _pending = null;
    _error = null;
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
