// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '学习助手';

  @override
  String get todayStudy => '今日学习';

  @override
  String get studyStatistics => '学习统计';

  @override
  String get settings => '设置';

  @override
  String get home => '首页';

  @override
  String get statistics => '统计';

  @override
  String get managePlans => '管理计划';

  @override
  String get editHomeHeadline => '编辑首页文案';

  @override
  String get homeHeadline => '首页文案';

  @override
  String get homeHeadlineHint => '写一句鼓励自己的话';

  @override
  String get homeHeadlineRequired => '请输入一句简短文案';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get headlineSaveFailed => '首页文案暂未写入本地，请稍后重试';

  @override
  String get todayPlan => '今日计划';

  @override
  String get planLoadFailed => '计划数据读取失败，请先检查本地数据，避免覆盖旧记录。';

  @override
  String get noPlansHome => '还没有学习计划。先创建一个小目标，开始今天的学习吧。';

  @override
  String get noPlans => '还没有学习计划';

  @override
  String get viewProgress => '查看进度';

  @override
  String get continueStudy => '继续学习';

  @override
  String get startStudy => '开始学习';

  @override
  String get planManagement => '计划管理';

  @override
  String get bulkDeleteTitle => '批量删除计划？';

  @override
  String get delete => '删除';

  @override
  String get deleteSaveFailed => '删除结果暂未写入本地，请稍后重试';

  @override
  String get deletePlanTitle => '删除计划？';

  @override
  String get undo => '撤销';

  @override
  String get done => '完成';

  @override
  String get bulkManage => '批量管理';

  @override
  String get noPlansManage => '还没有计划，点击“新增计划”开始吧。';

  @override
  String get backgroundPause => '后台自动暂停';

  @override
  String get addPlan => '新增计划';

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String get editPlan => '编辑计划';

  @override
  String get planName => '计划名称';

  @override
  String get planNameHint => '例如：阅读、Python、健身';

  @override
  String get planNameRequired => '请输入计划名称';

  @override
  String get dailyPlanDuration => '每日计划时长';

  @override
  String get savePlan => '保存计划';

  @override
  String get chooseIcon => '选择图标';

  @override
  String get hours => '小时';

  @override
  String get minutes => '分钟';

  @override
  String get seconds => '秒';

  @override
  String get durationEmpty => '请填写小时、分钟和秒';

  @override
  String get durationNonnegative => '时间只能输入非负整数';

  @override
  String get durationTooLarge => '时间数值过大，请缩短时长';

  @override
  String get durationRange => '分钟和秒须在 0 到 59 之间';

  @override
  String get durationPositive => '总时长必须大于 0 秒';

  @override
  String get todayOverview => '今日总览';

  @override
  String get planProgress => '各计划进度';

  @override
  String get studyTimer => '学习计时';

  @override
  String get planMissing => '这个计划已不存在';

  @override
  String get adjustTime => '调整时间';

  @override
  String get newRemainingTime => '新的剩余时间';

  @override
  String get timeSaveFailed => '学习进度暂未写入本地，请稍后重试';

  @override
  String get remainingTime => '剩余时间';

  @override
  String get studiedTime => '已学习时间';

  @override
  String get completedToday => '今日计划已完成';

  @override
  String get focusEncouragement => '专注当下，继续加油';

  @override
  String get pause => '暂停';

  @override
  String get start => '开始';

  @override
  String get appearance => '外观';

  @override
  String get themeMode => '主题模式';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightMode => '浅色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get language => '语言';

  @override
  String get chinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get timing => '计时';

  @override
  String get dailyResetTime => '每日重置时间';

  @override
  String get planSection => '计划';

  @override
  String get defaultPlanDuration => '新增计划默认时长';

  @override
  String get defaultDuration => '默认时长';

  @override
  String get confirmBeforeDelete => '删除计划前确认';

  @override
  String get dataManagement => '数据管理';

  @override
  String get restoreDefaults => '恢复默认设置';

  @override
  String get clearStudyData => '清空学习数据';

  @override
  String get clearAllData => '清空全部数据';

  @override
  String get settingsSaveFailed => '设置暂未写入本地，请稍后重试';

  @override
  String get restoreDefaultsTitle => '恢复默认设置？';

  @override
  String get restoreDefaultsMessage => '只恢复设置，不删除学习计划和历史记录。';

  @override
  String get restore => '恢复';

  @override
  String get clearStudyTitle => '清空学习数据？';

  @override
  String get clearStudyMessage => '这会清空今日进度和全部学习历史，保留现有计划。此操作无法撤销。';

  @override
  String get studyDataSaveFailed => '学习数据暂未写入本地，请稍后重试';

  @override
  String get clearAllTitle => '清空全部数据？';

  @override
  String get clearAllMessage => '所有计划、学习记录和设置都会恢复到首次安装状态。此操作无法撤销。';

  @override
  String get continueAction => '继续';

  @override
  String get clearAllAgainTitle => '再次确认清空全部数据';

  @override
  String get clearAllAgainMessage => '请确认：这会删除所有自定义计划和学习记录。';

  @override
  String get confirmClear => '确认清空';

  @override
  String get dataSaveFailed => '数据暂未全部写入本地，请稍后重试';

  @override
  String get timerAlert => '倒计时提醒';

  @override
  String get alertMode => '提醒方式';

  @override
  String get sound => '铃声';

  @override
  String get vibration => '震动';

  @override
  String get none => '无提醒';

  @override
  String get alertSound => '铃声选择';

  @override
  String get preview => '试听';

  @override
  String get sound1 => '柔和铃声';

  @override
  String get sound2 => '清脆铃声';

  @override
  String get sound3 => '数字提示';

  @override
  String get sound4 => '轻柔提示';

  @override
  String get sound5 => '短提示音';

  @override
  String get notificationPermissionHint => '通知或精确闹钟权限未开启，后台完成提醒可能延迟或无法显示。';

  @override
  String get notificationPermissionAction => '开启通知权限';

  @override
  String get studyCompleteTitle => '学习计划完成';

  @override
  String get completeSnack => '太棒了，今日学习计划完成！';

  @override
  String get iconLanguage => '语言';

  @override
  String get iconTranslate => '翻译';

  @override
  String get iconTextbook => '课本';

  @override
  String get iconSpeaking => '口语';

  @override
  String get iconCalculate => '计算';

  @override
  String get iconFunctions => '函数';

  @override
  String get iconScience => '科学';

  @override
  String get iconAnalytics => '分析';

  @override
  String get iconCode => '代码';

  @override
  String get iconTerminal => '终端';

  @override
  String get iconComputer => '电脑';

  @override
  String get iconDevelopment => '开发';

  @override
  String get iconMemory => '芯片';

  @override
  String get iconBook => '书籍';

  @override
  String get iconReading => '阅读';

  @override
  String get iconLibrary => '图书';

  @override
  String get iconFitness => '健身';

  @override
  String get iconRunning => '跑步';

  @override
  String get iconSports => '运动';

  @override
  String get iconMusic => '音乐';

  @override
  String get iconHeadphones => '耳机';

  @override
  String get iconChecklist => '清单';

  @override
  String get iconSchedule => '日程';

  @override
  String get iconWork => '工作';

  @override
  String get iconSchool => '学习';

  @override
  String get iconPsychology => '思考';

  @override
  String get iconLightbulb => '灵感';

  @override
  String get iconStar => '星星';

  @override
  String get iconFavorite => '喜爱';

  @override
  String get iconFlag => '目标';

  @override
  String get iconBolt => '能量';

  @override
  String get iconOther => '其他';

  @override
  String homeSummary(int count, String duration) {
    return '今天有 $count 项学习计划 · 共 $duration';
  }

  @override
  String todayRemainingDuration(String duration) {
    return '今日剩余 $duration';
  }

  @override
  String todayPlanDuration(String duration) {
    return '今日计划 $duration';
  }

  @override
  String planDuration(String duration) {
    return '计划 $duration';
  }

  @override
  String dailyPlanValue(String duration) {
    return '每日计划 $duration';
  }

  @override
  String bulkDeleteConfirm(int count) {
    return '确定删除已选择的 $count 个计划吗？';
  }

  @override
  String selectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String deletePlanConfirm(String planName) {
    return '确定删除“$planName”计划吗？';
  }

  @override
  String deletedPlan(String planName) {
    return '已删除“$planName”计划';
  }

  @override
  String editPlanTooltip(String planName) {
    return '编辑$planName计划';
  }

  @override
  String deletePlanTooltip(String planName) {
    return '删除$planName计划';
  }

  @override
  String deleteSelected(int count) {
    return '删除选中 ($count)';
  }

  @override
  String currentIcon(String label) {
    return '当前：$label';
  }

  @override
  String currentRemaining(String duration) {
    return '当前剩余 $duration';
  }

  @override
  String todayPlanTotal(String duration) {
    return '今日计划总时长 $duration';
  }

  @override
  String overviewPlanned(String duration) {
    return '今日计划总时长：$duration';
  }

  @override
  String overviewStudied(String duration) {
    return '今日已学习：$duration';
  }

  @override
  String overviewRemaining(String duration) {
    return '今日剩余：$duration';
  }

  @override
  String overviewCompletion(String percent) {
    return '今日完成率：$percent';
  }

  @override
  String statPlanned(String duration) {
    return '计划：$duration';
  }

  @override
  String statStudied(String duration) {
    return '已学习：$duration';
  }

  @override
  String statRemaining(String duration) {
    return '剩余：$duration';
  }

  @override
  String statOver(String duration) {
    return '超出计划：$duration';
  }

  @override
  String notificationBody(String planName) {
    return '“$planName”的计时已完成';
  }

  @override
  String get defaultHomeHeadline => '每天进步一点点';

  @override
  String get chooseLocalImage => '从本地选择图片';

  @override
  String get invalidLocalImage => '请选择小于 8 MB 的有效 PNG、JPEG 或 WebP 图片。';

  @override
  String get chooseLocalSound => '从本地选择铃声';

  @override
  String get invalidLocalSound => '无法使用该音频文件，请选择受支持的音频格式。';

  @override
  String get ncmUnsupported =>
      '该文件为网易云音乐 NCM 格式，无法直接作为铃声使用。请选择 MP3、WAV、M4A 或 OGG 等标准音频文件。';

  @override
  String get cropImage => '裁剪图片';

  @override
  String get trimSound => '裁剪铃声';

  @override
  String get audioDuration => '音频总时长';

  @override
  String get audioStart => '开始位置';

  @override
  String get audioEnd => '结束位置';

  @override
  String get clipLength => '片段长度';

  @override
  String get saveClip => '保存片段';

  @override
  String get customSound => '自定义铃声';

  @override
  String get previewFailed => '无法播放这个铃声。';

  @override
  String get customSoundBackgroundFallback =>
      '后台和锁屏时会尝试使用自定义铃声；若无法取得通知用的声音地址，则改用当前选定的内置铃声。';

  @override
  String get backgroundPauseUpdatedHint => '切换到其他应用时暂停；锁屏仍继续计时。';

  @override
  String get statisticsToday => '今日';

  @override
  String get recentWeek => '近 7 天';

  @override
  String get historyTotal => '近 7 天累计学习';

  @override
  String historyActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '7 天中有 $count 天学习',
      zero: '还没有学习记录',
    );
    return '$_temp0';
  }

  @override
  String historyDateRange(String startDate, String endDate) {
    return '$startDate 至 $endDate';
  }

  @override
  String get dailyStudyDuration => '每日实际学习';

  @override
  String get noRecentStudy => '近 7 天还没有学习时长记录，开始一次学习后即可查看。';

  @override
  String get historyExplanation => '学习日按设置的每日重置时间划分，包含已删除计划的历史记录。';

  @override
  String get historyBarExplanation => '条形长度以这 7 天学习时长最多的一天为基准。';

  @override
  String get plannedTime => '计划时长';

  @override
  String get completedPlans => '已完成计划';

  @override
  String completedPlansValue(int completed, int total) {
    return '$completed / $total';
  }

  @override
  String get timerReadyState => '未开始';

  @override
  String get timerRunningState => '计时中';

  @override
  String get timerPausedState => '已暂停';

  @override
  String get timerCompleteState => '已完成';

  @override
  String get backgroundPauseSettingHint => '在计划管理中逐项设置。开启后切换应用会暂停，锁屏继续计时。';

  @override
  String get planDetails => '计划信息';

  @override
  String get customPlanImage => '已选择自定义图片';

  @override
  String get savingPlan => '正在保存…';

  @override
  String get discardPlanTitle => '放弃修改？';

  @override
  String get discardPlanMessage => '这个计划的修改尚未保存。';

  @override
  String get keepEditing => '继续编辑';

  @override
  String get discardChanges => '放弃修改';

  @override
  String get planNotPersistedTitle => '修改尚未写入本地';

  @override
  String get planNotPersistedMessage => '计划仍保留在内存中，但离开后若应用关闭，修改可能丢失。继续编辑可重试保存。';

  @override
  String get leavePage => '离开';

  @override
  String get planFollowUpFailed => '计划已保存，但部分后续处理未完成，请重试。';

  @override
  String planCompletion(String percentage) {
    return '完成率：$percentage';
  }

  @override
  String get searchPlans => '搜索计划名称';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get filterAllPlans => '全部';

  @override
  String get filterNotStarted => '未开始';

  @override
  String get filterInProgress => '进行中';

  @override
  String get filterCompleted => '已完成';

  @override
  String planFilterCount(String label, int count) {
    return '$label · $count';
  }

  @override
  String get noMatchingPlans => '没有匹配的计划，试试其他名称或状态。';

  @override
  String get resetPlanFilters => '显示全部计划';

  @override
  String get bulkAllPlansHint => '批量选择显示全部计划；完成后恢复原来的搜索和筛选。';

  @override
  String get runningPlanHint => '计时正在继续';

  @override
  String get pickUpPlanHint => '接着完成这个计划';

  @override
  String get openRunningTimer => '查看计时';

  @override
  String get allPlansCompleted => '今天的计划已全部完成，学习进度已记录在统计中。';

  @override
  String get historyDailyAverage => '日均学习时长';

  @override
  String get historyBestDay => '最高单日时长';

  @override
  String historyBestDayDate(String date) {
    return '学习最多的一天：$date';
  }

  @override
  String get historyAverageExplanation => '日均按全部 7 个学习日计算，包含没有学习记录的日子。';

  @override
  String get studyReview => '学习复盘';

  @override
  String get reviewCalendar => '月历';

  @override
  String get reviewRange => '范围统计';

  @override
  String get reviewCurrentStreak => '当前连续学习';

  @override
  String get reviewLongestStreak => '最长连续学习';

  @override
  String reviewStudyDays(int count) {
    return '$count 天';
  }

  @override
  String get reviewNotStudiedToday => '今天还未学习，继续保持这份积累。';

  @override
  String get reviewNoHistory => '还没有学习记录，开始学习后就能查看复盘。';

  @override
  String get reviewStreakExplanation =>
      '当天有实际学习就计入学习日；今天结束前，保留截至昨天的连续值。学习日沿用设置中的每日重置时间。';

  @override
  String get reviewMonthTotal => '月累计学习';

  @override
  String get reviewActiveDays => '学习天数';

  @override
  String get reviewPreviousMonth => '上个月';

  @override
  String get reviewNextMonth => '下个月';

  @override
  String get reviewBackToMonth => '返回本月';

  @override
  String get reviewHeatNone => '0';

  @override
  String get reviewHeat15 => '≤15 分钟';

  @override
  String get reviewHeat30 => '≤30 分钟';

  @override
  String get reviewHeat60 => '≤60 分钟';

  @override
  String get reviewHeatOver60 => '>60 分钟';

  @override
  String reviewDayDescription(String date, String duration) {
    return '$date：已学习 $duration';
  }

  @override
  String reviewFutureDay(String date) {
    return '$date：尚未到来的学习日';
  }

  @override
  String get reviewFutureLabel => '尚未到来';

  @override
  String get reviewNoDayRecords => '这一天还没有学习时长记录。';

  @override
  String reviewDayTotal(String duration) {
    return '当日累计学习：$duration';
  }

  @override
  String reviewDeletedPlans(int count) {
    return '已删除计划（$count 项）';
  }

  @override
  String get reviewLast30Days => '近 30 天';

  @override
  String get reviewThisMonth => '本月';

  @override
  String get reviewCustomRange => '自定义';

  @override
  String get reviewTotal => '累计学习';

  @override
  String reviewAverageExplanation(int count) {
    return '日均按范围内全部 $count 个学习日计算，包含没有学习记录的日子。';
  }

  @override
  String get reviewRecordNamesHint => '现存计划显示当前名称；已删除计划合并展示，其学习时长仍然保留。';

  @override
  String get reviewClose => '关闭';

  @override
  String get reviewPeriodComparison => '上一周期对比';

  @override
  String reviewComparisonPeriod(int count, String start, String end) {
    return '前 $count 天：$start 至 $end';
  }

  @override
  String reviewTimeIncreased(String duration) {
    return '增加 $duration';
  }

  @override
  String reviewTimeDecreased(String duration) {
    return '减少 $duration';
  }

  @override
  String get reviewTimeUnchanged => '无变化';

  @override
  String reviewChangePercent(String percent) {
    return '变化：$percent';
  }

  @override
  String get reviewNoPreviousStudy => '上一周期无学习记录，不计算变化率。';

  @override
  String reviewPreviousTotal(String duration) {
    return '上一周期累计：$duration';
  }

  @override
  String get reviewPlanBreakdown => '计划时间分布';

  @override
  String get reviewBreakdownExplanation => '按实际学习时长排序，占比包含已删除计划。';

  @override
  String reviewTimeShare(String percent) {
    return '占比 $percent';
  }

  @override
  String reviewAllPlanTimes(int count) {
    return '查看全部（$count 项）';
  }

  @override
  String get reviewOnlyStudyDays => '只看学习日';

  @override
  String get reviewNoRangeStudy => '这个范围还没有学习时长记录。';

  @override
  String reviewRangeTotal(String duration) {
    return '范围累计学习：$duration';
  }
}
