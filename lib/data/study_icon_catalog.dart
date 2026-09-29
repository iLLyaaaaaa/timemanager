import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class StudyIconOption {
  const StudyIconOption(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

const studyIconOptions = <StudyIconOption>[
  StudyIconOption('language', '语言', Icons.language),
  StudyIconOption('translate', '翻译', Icons.translate),
  StudyIconOption('menu_book', '课本', Icons.menu_book),
  StudyIconOption('record_voice_over', '口语', Icons.record_voice_over),
  StudyIconOption('calculate', '计算', Icons.calculate),
  StudyIconOption('functions', '函数', Icons.functions),
  StudyIconOption('science', '科学', Icons.science),
  StudyIconOption('analytics', '分析', Icons.analytics),
  StudyIconOption('code', '代码', Icons.code),
  StudyIconOption('terminal', '终端', Icons.terminal),
  StudyIconOption('computer', '电脑', Icons.computer),
  StudyIconOption('developer_mode', '开发', Icons.developer_mode),
  StudyIconOption('memory', '芯片', Icons.memory),
  StudyIconOption('book', '书籍', Icons.book),
  StudyIconOption('auto_stories', '阅读', Icons.auto_stories),
  StudyIconOption('library_books', '图书', Icons.library_books),
  StudyIconOption('fitness_center', '健身', Icons.fitness_center),
  StudyIconOption('directions_run', '跑步', Icons.directions_run),
  StudyIconOption('sports', '运动', Icons.sports),
  StudyIconOption('music_note', '音乐', Icons.music_note),
  StudyIconOption('headphones', '耳机', Icons.headphones),
  StudyIconOption('checklist', '清单', Icons.checklist),
  StudyIconOption('schedule', '日程', Icons.schedule),
  StudyIconOption('work', '工作', Icons.work),
  StudyIconOption('school', '学习', Icons.school),
  StudyIconOption('psychology', '思考', Icons.psychology),
  StudyIconOption('lightbulb', '灵感', Icons.lightbulb),
  StudyIconOption('star', '星星', Icons.star),
  StudyIconOption('favorite', '喜爱', Icons.favorite),
  StudyIconOption('flag', '目标', Icons.flag),
  StudyIconOption('bolt', '能量', Icons.bolt),
  StudyIconOption('category', '其他', Icons.category),
];

StudyIconOption studyIconFor(String id) {
  for (final option in studyIconOptions) {
    if (option.id == id) return option;
  }
  return studyIconOptions.last;
}

String localizedStudyIconLabel(AppLocalizations l10n, String id) =>
    switch (id) {
      'language' => l10n.iconLanguage,
      'translate' => l10n.iconTranslate,
      'menu_book' => l10n.iconTextbook,
      'record_voice_over' => l10n.iconSpeaking,
      'calculate' => l10n.iconCalculate,
      'functions' => l10n.iconFunctions,
      'science' => l10n.iconScience,
      'analytics' => l10n.iconAnalytics,
      'code' => l10n.iconCode,
      'terminal' => l10n.iconTerminal,
      'computer' => l10n.iconComputer,
      'developer_mode' => l10n.iconDevelopment,
      'memory' => l10n.iconMemory,
      'book' => l10n.iconBook,
      'auto_stories' => l10n.iconReading,
      'library_books' => l10n.iconLibrary,
      'fitness_center' => l10n.iconFitness,
      'directions_run' => l10n.iconRunning,
      'sports' => l10n.iconSports,
      'music_note' => l10n.iconMusic,
      'headphones' => l10n.iconHeadphones,
      'checklist' => l10n.iconChecklist,
      'schedule' => l10n.iconSchedule,
      'work' => l10n.iconWork,
      'school' => l10n.iconSchool,
      'psychology' => l10n.iconPsychology,
      'lightbulb' => l10n.iconLightbulb,
      'star' => l10n.iconStar,
      'favorite' => l10n.iconFavorite,
      'flag' => l10n.iconFlag,
      'bolt' => l10n.iconBolt,
      'category' => l10n.iconOther,
      _ => l10n.iconOther,
    };
