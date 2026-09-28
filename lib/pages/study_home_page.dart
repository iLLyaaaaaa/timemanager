import 'package:flutter/material.dart';

import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import '../widgets/study_plan_card.dart';
import 'plan_management_page.dart';
import 'settings_page.dart';
import 'study_statistics_page.dart';
import 'study_timer_page.dart';

class StudyHomePage extends StatefulWidget {
  const StudyHomePage({super.key, required this.store, this.settings});

  final StudyPlanStore store;
  final SettingsStore? settings;

  @override
  State<StudyHomePage> createState() => _StudyHomePageState();
}

class _StudyHomePageState extends State<StudyHomePage> {
  int _selectedIndex = 0;
  late final SettingsStore _settings = widget.settings ?? SettingsStore();

  @override
  void dispose() {
    if (widget.settings == null) _settings.dispose();
    super.dispose();
  }

  void _openManagement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlanManagementPage(store: widget.store, settings: _settings),
      ),
    );
  }

  void _startStudy(StudyPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyTimerPage(
          store: widget.store,
          planId: plan.id,
          settings: _settings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['今日学习', '学习统计', '设置'];

    return AnimatedBuilder(
      animation: Listenable.merge([widget.store, _settings]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(titles[_selectedIndex]),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          actions: _selectedIndex == 0
              ? [
                  TextButton.icon(
                    onPressed: _openManagement,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('管理计划'),
                  ),
                  const SizedBox(width: 8),
                ]
              : null,
        ),
        body: switch (_selectedIndex) {
          0 => _buildHome(context),
          1 => StudyStatisticsPage(store: widget.store),
          _ => SettingsPage(settings: _settings, plans: widget.store),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            widget.store.refreshForToday();
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: '统计',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final plans = widget.store.plans;
    final colors = Theme.of(context).colorScheme;
    final totalSeconds = plans.fold<int>(
      0,
      (total, plan) => total + plan.plannedSeconds,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '每天进步一点点',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '今天有 ${plans.length} 项学习计划 · 共 ${formatStudyDuration(totalSeconds)}',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '今日计划',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (plans.isEmpty)
          Card(
            elevation: 0,
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.store.hasLoadError
                    ? '计划数据读取失败，请先检查本地数据，避免覆盖旧记录。'
                    : '还没有学习计划，点击右上角“管理计划”新增。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (final plan in plans) ...[
            StudyPlanCard(plan: plan, onStart: () => _startStudy(plan)),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
