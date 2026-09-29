import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/local_media_store.dart';

class SoundTrimSelection {
  const SoundTrimSelection(this.startMilliseconds, this.endMilliseconds);
  final int startMilliseconds;
  final int endMilliseconds;
}

class SoundTrimPage extends StatefulWidget {
  const SoundTrimPage({super.key, required this.sound});

  final PickedLocalSound sound;

  @override
  State<SoundTrimPage> createState() => _SoundTrimPageState();
}

class _SoundTrimPageState extends State<SoundTrimPage> {
  final _player = AudioPlayer();
  Timer? _previewStop;
  late final int _totalSeconds = widget.sound.duration.inSeconds;
  int _startSeconds = 0;
  late int _endSeconds = _totalSeconds.clamp(1, 10);
  bool _previewing = false;

  @override
  void dispose() {
    _previewStop?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _stopPreview() async {
    _previewStop?.cancel();
    if (_previewing) {
      try {
        await _player.stop();
      } catch (_) {
        // A removed source or audio-device failure must not block editing.
      }
    }
    if (mounted) setState(() => _previewing = false);
  }

  Future<void> _preview() async {
    try {
      await _stopPreview();
      await _player.setAudioContext(
        AudioContextConfig(respectSilence: true).build(),
      );
      await _player.play(
        DeviceFileSource(widget.sound.path),
        position: Duration(seconds: _startSeconds),
      );
      if (!mounted) return;
      setState(() => _previewing = true);
      _previewStop = Timer(
        Duration(seconds: _endSeconds - _startSeconds),
        () => unawaited(_stopPreview()),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.previewFailed)),
        );
      }
    }
  }

  String _format(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final endMaximum = (_startSeconds + 30).clamp(1, _totalSeconds);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trimSound)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              widget.sound.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('${l10n.audioDuration}: ${_format(_totalSeconds)}'),
            const SizedBox(height: 24),
            Text('${l10n.audioStart}: ${_format(_startSeconds)}'),
            Slider(
              value: _startSeconds.toDouble(),
              min: 0,
              max: (_totalSeconds - 1).toDouble(),
              divisions: _totalSeconds > 1 ? _totalSeconds - 1 : null,
              onChanged: _totalSeconds <= 1
                  ? null
                  : (value) {
                      unawaited(_stopPreview());
                      setState(() {
                        _startSeconds = value.round();
                        _endSeconds = _endSeconds.clamp(
                          _startSeconds + 1,
                          (_startSeconds + 30).clamp(1, _totalSeconds),
                        );
                      });
                    },
            ),
            const SizedBox(height: 12),
            Text('${l10n.audioEnd}: ${_format(_endSeconds)}'),
            Slider(
              value: _endSeconds.toDouble(),
              min: (_startSeconds + 1).toDouble(),
              max: endMaximum.toDouble(),
              divisions: endMaximum - _startSeconds - 1 > 0
                  ? endMaximum - _startSeconds - 1
                  : null,
              onChanged: endMaximum <= _startSeconds + 1
                  ? null
                  : (value) {
                      unawaited(_stopPreview());
                      setState(() => _endSeconds = value.round());
                    },
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.clipLength}: ${_format(_endSeconds - _startSeconds)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _previewing ? _stopPreview : _preview,
              icon: Icon(
                _previewing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(l10n.preview),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    SoundTrimSelection(
                      _startSeconds * 1000,
                      _endSeconds * 1000,
                    ),
                  ),
                  child: Text(l10n.saveClip),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
