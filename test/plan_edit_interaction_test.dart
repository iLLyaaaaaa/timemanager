import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/study_plan_storage.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/models/study_plan.dart';
import 'package:hello_app/pages/plan_edit_page.dart';
import 'package:hello_app/pages/plan_management_page.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_statistics_page.dart';
import 'package:hello_app/services/local_media_store.dart';

import 'support/localized_app.dart';

class _Storage implements StudyPlanStorage {
  String? value;
  bool failWrites = false;
  Completer<void>? gate;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String snapshot) async {
    writes++;
    await gate?.future;
    if (failWrites) throw const FileSystemException('Simulated disk failure');
    value = snapshot;
  }
}

class _Media extends LocalMediaStore {
  _Media(this.nextPath);
  String nextPath;
  final deleted = <String>[];

  @override
  Future<SavedLocalMedia?> chooseIcon({required String cropTitle}) async =>
      SavedLocalMedia(nextPath, 'image.png');

  @override
  Future<void> deleteIfManaged(String? filePath, String kind) async {
    if (filePath == null) return;
    deleted.add(filePath);
  }
}

Future<void> _openEditor(
  WidgetTester tester,
  StudyPlanStore store, {
  StudyPlan? plan,
  LocalMediaStore? media,
}) async {
  await tester.pumpWidget(
    localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            key: const ValueKey('open_editor'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    PlanEditPage(store: store, plan: plan, media: media),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open_editor')));
  await tester.pumpAndSettle();
}

Future<void> _chooseImage(WidgetTester tester) async {
  final choose = find.byKey(const ValueKey('choose_plan_image'));
  await tester.ensureVisible(choose);
  await tester.pumpAndSettle();
  await tester.tap(choose);
  await tester.pumpAndSettle();
}

String get _imageRoot =>
    '${Directory.systemTemp.path}/timemanager-editor-fixture';

void main() {
  testWidgets('unchanged editor returns without confirmation', (tester) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    await _openEditor(tester, store);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PlanEditPage), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.plans, isEmpty);
  });

  testWidgets(
    'toolbar and system back share confirmation and retain cancelled input',
    (tester) async {
      final store = StudyPlanStore();
      addTearDown(store.dispose);
      await _openEditor(tester, store);
      await tester.enterText(find.byKey(const ValueKey('plan_name')), '阅读');
      await tester.tap(find.byKey(const ValueKey('editor_back')));
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('keep_editing')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('plan_name')))
            .controller!
            .text,
        '阅读',
      );
      expect(store.plans, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('leave_editor')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanEditPage), findsNothing);
      expect(store.plans, isEmpty);
    },
  );

  testWidgets('restoring name duration and icon clears unsaved changes', (
    tester,
  ) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    final plan = store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    await _openEditor(tester, store, plan: plan);
    await tester.enterText(find.byKey(const ValueKey('plan_name')), '别的名称');
    await tester.enterText(find.byKey(const ValueKey('plan_name')), ' 阅读 ');
    await tester.enterText(find.byKey(const ValueKey('duration_minutes')), '2');
    await tester.enterText(
      find.byKey(const ValueKey('duration_minutes')),
      '01',
    );
    for (final id in ['code', 'book']) {
      final option = find.byKey(ValueKey('icon_option_$id'));
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pump();
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PlanEditPage), findsNothing);
    expect(store.plans.single.name, '阅读');
    expect(store.plans.single.plannedSeconds, 90);
  });

  testWidgets('invalid duration alone is detected as unsaved', (tester) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    await _openEditor(tester, store);
    await tester.enterText(
      find.byKey(const ValueKey('duration_minutes')),
      '60',
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃修改？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('keep_editing')));
    await tester.pumpAndSettle();
  });

  testWidgets('saving blocks duplicate clicks edits and both return paths', (
    tester,
  ) async {
    final storage = _Storage()..gate = Completer<void>();
    final store = await StudyPlanStore.load(storage: storage);
    addTearDown(store.dispose);
    await _openEditor(tester, store);
    await tester.enterText(find.byKey(const ValueKey('plan_name')), 'Python');
    final save = find.byKey(const ValueKey('save_plan'));
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();
    expect(find.text('正在保存…'), findsOneWidget);
    expect(store.plans, hasLength(1));
    expect(storage.writes, 1);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('plan_name')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('duration_hours')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('editor_back')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(PlanEditPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    storage.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PlanEditPage), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'failed save retains draft and retries the same plan ID durably',
    (tester) async {
      final storage = _Storage()..failWrites = true;
      final store = await StudyPlanStore.load(storage: storage);
      addTearDown(store.dispose);
      await _openEditor(tester, store);
      await tester.enterText(find.byKey(const ValueKey('plan_name')), '阅读');
      await tester.tap(find.byKey(const ValueKey('save_plan')));
      await tester.pumpAndSettle();
      final id = store.plans.single.id;
      expect(find.byType(PlanEditPage), findsOneWidget);
      expect(find.textContaining('暂未全部写入本地'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('修改尚未写入本地'), findsOneWidget);
      expect(find.text('放弃修改'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('keep_editing')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('plan_name')), '精读');
      storage.failWrites = false;
      await tester.tap(find.byKey(const ValueKey('save_plan')));
      await tester.pumpAndSettle();
      expect(store.plans, hasLength(1));
      expect(store.plans.single.id, id);
      final reopened = await StudyPlanStore.load(storage: storage);
      addTearDown(reopened.dispose);
      expect(reopened.plans.single.id, id);
      expect(reopened.plans.single.name, '精读');
      expect(find.byType(PlanEditPage), findsNothing);
    },
  );

  testWidgets(
    'keyboard actions advance through all fields and done dismisses',
    (tester) async {
      final store = StudyPlanStore();
      addTearDown(store.dispose);
      await _openEditor(tester, store);
      await tester.showKeyboard(find.byKey(const ValueKey('plan_name')));
      for (final key in [
        'duration_hours',
        'duration_minutes',
        'duration_seconds',
      ]) {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey(key)))
              .focusNode!
              .hasFocus,
          isTrue,
        );
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('duration_seconds')))
            .focusNode!
            .hasFocus,
        isFalse,
      );
      expect(store.plans, isEmpty);
    },
  );

  testWidgets('keyboard leaves save visible and invalid fields are revealed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    await _openEditor(tester, store);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save_plan'));
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(360));
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('请输入计划名称'), findsOneWidget);
    final name = find.byKey(const ValueKey('plan_name'));
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: name, matching: find.byType(TextField)),
          )
          .focusNode!
          .hasFocus,
      isTrue,
    );
    expect(tester.getRect(name).top, greaterThanOrEqualTo(56));
    expect(
      tester.getRect(name).bottom,
      lessThanOrEqualTo(tester.getRect(save).top),
    );
    await tester.enterText(name, '阅读');
    await tester.enterText(
      find.byKey(const ValueKey('duration_minutes')),
      '60',
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final minutes = find.byKey(const ValueKey('duration_minutes'));
    expect(tester.widget<TextField>(minutes).focusNode!.hasFocus, isTrue);
    expect(tester.getRect(minutes).top, greaterThanOrEqualTo(56));
    expect(
      tester.getRect(minutes).bottom,
      lessThanOrEqualTo(tester.getRect(save).top),
    );
    expect(store.plans, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'image-only draft asks before leaving and discarded image is cleaned',
    (tester) async {
      final directory = _imageRoot;
      final path = '$directory/draft.png';
      final media = _Media(path);
      final store = StudyPlanStore();
      addTearDown(store.dispose);
      await _openEditor(tester, store, media: media);
      await _chooseImage(tester);
      expect(find.text('已选择自定义图片'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('leave_editor')));
      await tester.pumpAndSettle();
      expect(media.deleted, contains(path));
      expect(store.plans, isEmpty);
    },
  );

  testWidgets(
    'failed image save preserves memory reference and persisted original on exit',
    (tester) async {
      final directory = _imageRoot;
      final original = '$directory/original.png';
      final draft = '$directory/draft.png';
      final media = _Media(draft);
      final storage = _Storage();
      final store = await StudyPlanStore.load(storage: storage);
      addTearDown(store.dispose);
      final plan = store.addPlan(
        name: '阅读',
        iconId: 'book',
        plannedSeconds: 90,
        customIconPath: original,
      );
      await store.flush();
      storage.failWrites = true;
      await _openEditor(tester, store, plan: plan, media: media);
      await _chooseImage(tester);
      await tester.tap(find.byKey(const ValueKey('save_plan')));
      await tester.pumpAndSettle();
      expect(store.plans.single.customIconPath, draft);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('leave_editor')));
      await tester.pumpAndSettle();
      expect(media.deleted, isEmpty);
      final reopened = await StudyPlanStore.load(storage: storage);
      addTearDown(reopened.dispose);
      expect(reopened.plans.single.customIconPath, original);
    },
  );

  testWidgets(
    'successful image replacement preserves files referenced by another plan',
    (tester) async {
      final directory = _imageRoot;
      final original = '$directory/original.png';
      final draft = '$directory/draft.png';
      final media = _Media(draft);
      final store = StudyPlanStore();
      addTearDown(store.dispose);
      final plan = store.addPlan(
        name: '阅读',
        iconId: 'book',
        plannedSeconds: 90,
        customIconPath: original,
      );
      store.addPlan(
        name: '英语',
        iconId: 'book',
        plannedSeconds: 60,
        customIconPath: original,
      );
      await _openEditor(tester, store, plan: plan, media: media);
      await _chooseImage(tester);
      await tester.tap(find.byKey(const ValueKey('save_plan')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanEditPage), findsNothing);
      expect(store.plans.first.customIconPath, draft);
      expect(store.plans.last.customIconPath, original);
      expect(media.deleted, isEmpty);
    },
  );

  testWidgets('management empty state opens editor directly', (tester) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      localizedApp(home: PlanManagementPage(store: store)),
    );
    await tester.tap(find.byKey(const ValueKey('management_empty_add')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanEditPage), findsOneWidget);
    expect(find.text('新增计划'), findsOneWidget);
  });

  testWidgets(
    'compact management reserves space for add and retains bulk actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final store = StudyPlanStore();
      addTearDown(store.dispose);
      store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
      final last = store.addPlan(
        name: '英语',
        iconId: 'language',
        plannedSeconds: 60,
      );
      await tester.pumpWidget(
        localizedApp(home: PlanManagementPage(store: store)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
      final add = find.byKey(const ValueKey('add_plan_compact'));
      final toggle = find.byKey(const ValueKey('toggle_bulk_mode'));
      final pause = find.byKey(ValueKey('background_pause_${last.id}'));
      await tester.scrollUntilVisible(
        pause,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(pause);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(pause).bottom,
        lessThanOrEqualTo(tester.getRect(add).top),
      );
      await tester.tap(pause);
      await tester.pumpAndSettle();
      expect(store.planById(last.id)!.pauseWhenBackgrounded, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(add, findsNothing);
      expect(find.text('删除选中 (0)'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(PlanEditPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'all plan cards use accessible responsive layout at $width scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final semantics = tester.ensureSemantics();
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final store = StudyPlanStore();
          addTearDown(store.dispose);
          const name = '高等数学与线性代数 Advanced Mathematics';
          final plan = store.addPlan(
            name: name,
            iconId: 'book',
            plannedSeconds: 3600,
          );
          final stacked = width == 320 || scale == 1.5;
          final pages = <String, Widget>{
            'plan': StudyHomePage(store: store),
            'manage': PlanManagementPage(store: store),
            'statistics': Scaffold(body: StudyStatisticsPage(store: store)),
          };
          try {
            for (final page in pages.entries) {
              await tester.pumpWidget(
                localizedApp(home: page.value, locale: const Locale('en')),
              );
              await tester.pumpAndSettle();
              final icon = find.byKey(ValueKey('${page.key}_icon_${plan.id}'));
              await tester.scrollUntilVisible(
                icon,
                200,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.ensureVisible(icon);
              await tester.pumpAndSettle();
              expect(tester.getSize(icon), const Size(112, 112));
              final title = find.text(name);
              expect(tester.widget<Text>(title).maxLines, 2);
              expect(tester.getSemantics(title).label, contains(name));
              final iconRect = tester.getRect(icon);
              final titleRect = tester.getRect(title);
              if (stacked) {
                expect(titleRect.top, greaterThan(iconRect.bottom));
              } else {
                expect(titleRect.left, greaterThan(iconRect.right));
              }
              if (page.key == 'plan') {
                final button = tester.getRect(
                  find.byKey(ValueKey('start_plan_${plan.id}')),
                );
                expect(button.width, stacked ? width - 72 : 112);
                expect(button.height, greaterThanOrEqualTo(48));
                expect(find.text('Start Studying'), findsOneWidget);
              }
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
            }
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
