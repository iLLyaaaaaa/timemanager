import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/pages/sound_trim_page.dart';
import 'package:hello_app/services/local_media_store.dart';

import 'support/localized_app.dart';

void main() {
  test('accepts standard audio names and rejects NCM or unsupported files', () {
    for (final extension in ['mp3', 'wav', 'm4a', 'ogg', 'MP3']) {
      expect(
        () => LocalMediaStore.validateSoundName('alert.$extension'),
        returnsNormally,
      );
    }
    expect(
      () => LocalMediaStore.validateSoundName('protected.ncm'),
      throwsA(isA<UnsupportedNcmSound>()),
    );
    expect(
      () => LocalMediaStore.validateSoundName('notes.txt'),
      throwsFormatException,
    );
  });

  testWidgets('sound trim defaults to a ten second clip and returns it', (
    tester,
  ) async {
    SoundTrimSelection? selected;
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.push<SoundTrimSelection>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SoundTrimPage(
                      sound: PickedLocalSound(
                        'temporary.mp3',
                        'sample.mp3',
                        Duration(seconds: 90),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('音频总时长: 01:30'), findsOneWidget);
    expect(find.text('片段长度: 00:10'), findsOneWidget);
    await tester.tap(find.text('保存片段'));
    await tester.pumpAndSettle();
    expect(selected?.startMilliseconds, 0);
    expect(selected?.endMilliseconds, 10000);
  });

  testWidgets('one second audio keeps a valid selection', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: const SoundTrimPage(
          sound: PickedLocalSound(
            'temporary.wav',
            'short.wav',
            Duration(seconds: 1),
          ),
        ),
      ),
    );
    expect(find.text('片段长度: 00:01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
