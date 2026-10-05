import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/models/study_plan.dart';
import 'package:hello_app/utils/study_history.dart';
import 'package:hello_app/utils/study_plan_breakdown.dart';
import 'package:hello_app/widgets/study_review_insights.dart';

import 'support/localized_app.dart';

const _plans = [
  StudyPlan(id: 'one', name: '数学', iconId: 'book', plannedSeconds: 90),
  StudyPlan(id: 'two', name: '数学', iconId: 'book', plannedSeconds: 90),
];

void main() {
  test(
    'plan breakdown keeps distinct IDs and groups removed plans by time',
    () {
      final result = studyPlanTimes(
        secondsByPlan: {
          'one': 30,
          'two': 30,
          'deleted1': 50,
          'deleted2': 20,
          'zero': 0,
          'negative': -2,
        },
        plans: _plans,
        deletedPlansLabel: (count) => 'Deleted $count',
      );
      expect(result.map((entry) => entry.id), ['', 'one', 'two']);
      expect(result.map((entry) => entry.seconds), [70, 30, 30]);
      expect(result.first.name, 'Deleted 2');
      expect(result[1].name, result[2].name);
      expect(() => result.clear(), throwsUnsupportedError);
    },
  );

  test('plan breakdown resolves current names and has a real empty state', () {
    final source = {'one': 30, 'two': 20};
    final renamed = _plans.first.copyWith(name: '新名称');
    final result = studyPlanTimes(
      secondsByPlan: source,
      plans: [renamed],
      deletedPlansLabel: (count) => 'Deleted $count',
    );
    expect(result.first.name, '新名称');
    expect(result.last.name, 'Deleted 1');
    expect(source, {'one': 30, 'two': 20});
    expect(
      studyPlanTimes(
        secondsByPlan: {'one': 0},
        plans: _plans,
        deletedPlansLabel: (count) => 'Deleted $count',
      ),
      isEmpty,
    );
  });

  testWidgets(
    'comparison explains positive, negative, equal and zero baselines',
    (tester) async {
      StudyRangeSummary summary(DateTime date, int seconds) =>
          StudyRangeSummary(
            startDay: date,
            endDay: date,
            totalStudiedSeconds: seconds,
            activeDays: seconds > 0 ? 1 : 0,
            longestStudyDay: null,
          );
      for (final (current, previous, change, percent) in [
        (90, 60, '增加 00:30', '变化：+50%'),
        (30, 60, '减少 00:30', '变化：-50%'),
        (0, 60, '减少 01:00', '变化：-100%'),
        (60, 60, '无变化', '变化：0%'),
        (60, 0, '增加 01:00', '上一周期无学习记录，不计算变化率。'),
        (0, 0, '无变化', '上一周期无学习记录，不计算变化率。'),
      ]) {
        await tester.pumpWidget(
          localizedApp(
            home: Scaffold(
              body: StudyPeriodComparisonCard(
                comparison: StudyPeriodComparison(
                  current: summary(DateTime.utc(2026, 10, 4), current),
                  previous: summary(DateTime.utc(2026, 10, 3), previous),
                ),
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('review_comparison_change')),
              )
              .data,
          change,
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('review_comparison_percent')),
              )
              .data,
          percent,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
