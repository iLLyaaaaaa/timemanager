import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import '../utils/study_plan_query.dart';
import '../widgets/study_plan_filter_bar.dart';
import '../widgets/study_plan_card.dart';
import '../widgets/app_section_card.dart';
import '../theme/app_theme.dart';
import 'plan_edit_page.dart';
import 'plan_management_page.dart';
import 'settings_page.dart';
import 'study_statistics_page.dart';
import 'study_timer_page.dart';
import '../services/screen_state_service.dart';

class StudyHomePage extends StatefulWidget {
  const StudyHomePage({
    super.key,
    required this.store,
    this.settings,
    this.screenState,
  });

  final StudyPlanStore store;
  final SettingsStore? settings;
  final ScreenStateService? screenState;

  @override
  State<StudyHomePage> createState() => _StudyHomePageState();
}

class _StudyHomePageState extends State<StudyHomePage> {
  int _selectedIndex = 0;
  final _pageStorage = PageStorageBucket();
  final _searchController = TextEditingController();
  StudyPlanFilter _filter = StudyPlanFilter.all;
  late final SettingsStore _settings = widget.settings ?? SettingsStore();

  @override
  void dispose() {
    _searchController.dispose();
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

  void _addPlan() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanEditPage(store: widget.store, settings: _settings),
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
          screenState: widget.screenState,
        ),
      ),
    );
  }

  Future<void> _editHeadline() async {
    var input = _settings.settings.homeHeadlineCustomized
        ? _settings.settings.homeHeadline
        : AppLocalizations.of(context)!.defaultHomeHeadline;
    final formKey = GlobalKey<FormState>();
    final headline = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.editHomeHeadline),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const ValueKey('home_headline_input'),
            initialValue: input,
            autofocus: true,
            maxLines: 1,
            maxLength: 40,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.homeHeadline,
              hintText: AppLocalizations.of(context)!.homeHeadlineHint,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => input = value,
            validator: (value) => value == null || value.trim().isEmpty
                ? AppLocalizations.of(context)!.homeHeadlineRequired
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, input.trim());
              }
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
    if (!mounted || headline == null) return;
    _settings.update(
      _settings.settings.copyWith(
        homeHeadline: headline,
        homeHeadlineCustomized: true,
      ),
    );
    if (!await _settings.flush() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.headlineSaveFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titles = [l10n.todayStudy, l10n.studyStatistics, l10n.settings];

    return AnimatedBuilder(
      animation: Listenable.merge([widget.store, _settings]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            titles[_selectedIndex],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          actions: _selectedIndex == 0
              ? [
                  if (MediaQuery.sizeOf(context).width < 360 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.2)
                    IconButton(
                      onPressed: _openManagement,
                      tooltip: l10n.managePlans,
                      icon: const Icon(Icons.tune_rounded),
                    )
                  else
                    TextButton.icon(
                      onPressed: _openManagement,
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(AppLocalizations.of(context)!.managePlans),
                    ),
                  const SizedBox(width: 8),
                ]
              : null,
        ),
        body: PageStorage(
          bucket: _pageStorage,
          child: switch (_selectedIndex) {
            0 => _buildHome(context),
            1 => StudyStatisticsPage(store: widget.store),
            _ => SettingsPage(settings: _settings, plans: widget.store),
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            FocusScope.of(context).unfocus();
            widget.store.refreshForToday();
            setState(() => _selectedIndex = index);
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: AppLocalizations.of(context)!.home,
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: AppLocalizations.of(context)!.statistics,
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: AppLocalizations.of(context)!.settings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final plans = widget.store.plans;
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final totalSeconds = plans.fold<int>(
      0,
      (total, plan) => total + plan.plannedSeconds,
    );
    final studiedSeconds = plans.fold<int>(
      0,
      (total, plan) => total + plan.studiedSeconds,
    );
    final completedPlans = plans.where((plan) => plan.isCompletedToday).length;
    final continuePlan = planToContinue(plans);
    final visiblePlans = filterStudyPlans(
      plans,
      query: _searchController.text,
      filter: _filter,
    );

    return ListView(
      key: const PageStorageKey('home_scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        12,
        AppTheme.pagePadding,
        24,
      ),
      children: [
        AppSectionCard(
          highlighted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _settings.settings.homeHeadlineCustomized
                          ? _settings.settings.homeHeadline
                          : AppLocalizations.of(context)!.defaultHomeHeadline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.editHomeHeadline,
                    onPressed: _editHeadline,
                    icon: const Icon(Icons.edit_outlined),
                    color: colors.onPrimaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(
                  context,
                )!.homeSummary(plans.length, formatStudyDuration(totalSeconds)),
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 20),
              AppMetricGrid(
                children: [
                  AppMetric(
                    label: l10n.studiedTime,
                    value: formatStudyDuration(studiedSeconds),
                    valueKey: const ValueKey('home_studied_total'),
                    foreground: colors.onPrimaryContainer,
                  ),
                  AppMetric(
                    label: l10n.completedPlans,
                    value: l10n.completedPlansValue(
                      completedPlans,
                      plans.length,
                    ),
                    valueKey: const ValueKey('home_completed_total'),
                    foreground: colors.onPrimaryContainer,
                  ),
                ],
              ),
              if (continuePlan != null) ...[
                const Divider(height: 32),
                Text(
                  continuePlan.isRunning
                      ? l10n.runningPlanHint
                      : l10n.pickUpPlanHint,
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 6),
                Text(
                  continuePlan.name,
                  semanticsLabel: continuePlan.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('home_resume_plan'),
                    onPressed: () => _startStudy(continuePlan),
                    icon: Icon(
                      continuePlan.isRunning
                          ? Icons.timer_outlined
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      continuePlan.isRunning
                          ? l10n.openRunningTimer
                          : l10n.continueStudy,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ] else if (plans.isNotEmpty &&
                  completedPlans == plans.length) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.allPlansCompleted,
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              l10n.todayPlan,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              key: const ValueKey('home_add_plan'),
              onPressed: widget.store.hasLoadError ? null : _addPlan,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(l10n.addPlan),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (plans.isNotEmpty) ...[
          StudyPlanFilterBar(
            plans: plans,
            controller: _searchController,
            filter: _filter,
            onQueryChanged: (_) => setState(() {}),
            onFilterChanged: (filter) => setState(() => _filter = filter),
          ),
          const SizedBox(height: 16),
        ],
        if (plans.isEmpty)
          AppSectionCard(
            child: Column(
              children: [
                Icon(
                  widget.store.hasLoadError
                      ? Icons.error_outline_rounded
                      : Icons.auto_stories_rounded,
                  size: 48,
                  color: widget.store.hasLoadError
                      ? colors.error
                      : colors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.store.hasLoadError
                      ? l10n.planLoadFailed
                      : l10n.noPlansHome,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!widget.store.hasLoadError) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('empty_add_plan'),
                    onPressed: _addPlan,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.addPlan),
                  ),
                ],
              ],
            ),
          )
        else if (visiblePlans.isEmpty)
          StudyPlanSearchEmpty(
            onReset: () => setState(() {
              _searchController.clear();
              _filter = StudyPlanFilter.all;
            }),
          )
        else
          for (final plan in visiblePlans) ...[
            StudyPlanCard(plan: plan, onStart: () => _startStudy(plan)),
            const SizedBox(height: AppTheme.cardSpacing),
          ],
      ],
    );
  }
}
