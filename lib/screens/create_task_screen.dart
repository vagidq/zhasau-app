import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import '../theme/app_colors.dart';
import '../services/google_calendar_service.dart';
import '../services/habit_service.dart';
import '../models/habit_model.dart';
import '../models/app_store.dart';
import '../models/goal_model.dart';
import '../models/goal_xp_rules.dart';
import '../models/task_model.dart';
import 'main_shell.dart';

class CreateTaskScreen extends StatefulWidget {
  final bool isFullPage;

  /// Если задан — экран открыт из карточки цели: цель предвыбрана и закреплена.
  final String? initialGoalId;

  /// Редактирование существующей задачи цели (только пока [TaskModel.completed] == false).
  final TaskModel? taskToEdit;

  /// Редактирование привычки с главной (без цели).
  final HabitModel? habitToEdit;

  const CreateTaskScreen({
    super.key,
    this.isFullPage = false,
    this.initialGoalId,
    this.taskToEdit,
    this.habitToEdit,
  }) : assert(
          taskToEdit == null || habitToEdit == null,
          'taskToEdit и habitToEdit не задаются одновременно',
        );

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  int _priority = 1; // 0=Low, 1=Med, 2=High
  double _complexity = 2;
  bool _repeat = false;
  int _repeatIndex = 0;
  bool _syncToCalendar = true;
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Google Calendar events for selected date
  List<gcal.Event> _dayEvents = [];
  bool _loadingEvents = false;

  final _priorities = ['Низкий', 'Средний', 'Высокий'];
  final _repeats = ['Ежедневно', 'Еженедельно', 'Ежемесячно'];

  final HabitService _habitService = HabitService();

  /// `null` — задача без цели (сохраняется как привычка). Иначе — `TaskModel` с [goalId].
  String? _selectedGoalId;

  bool get _isEditing =>
      widget.taskToEdit != null || widget.habitToEdit != null;

  /// Цель «заморожена» при создании из карточки цели или при редактировании задачи цели.
  String? get _lockedGoalId =>
      widget.taskToEdit?.goalId ?? widget.initialGoalId;

  @override
  void initState() {
    super.initState();
    _selectedGoalId = widget.initialGoalId;
    final edit = widget.taskToEdit;
    if (edit != null) {
      _titleController.text = edit.title;
      final sub = edit.subtitle;
      _descController.text = sub.startsWith('Цель: ') ? '' : sub;
      _priority = _priorityIndexFromTag(edit.tag);
      _selectedGoalId = edit.goalId;
      final st = edit.scheduledAt;
      if (st != null) {
        _selectedDate = DateTime(st.year, st.month, st.day);
        _selectedTime = TimeOfDay(hour: st.hour, minute: st.minute);
      }
    }

    final habitEdit = widget.habitToEdit;
    if (habitEdit != null) {
      _titleController.text = habitEdit.title;
      _descController.text = habitEdit.notes;
      _selectedGoalId = null;
      if (habitEdit.deadline != null) {
        final d = habitEdit.deadline!;
        _selectedDate = DateTime(d.year, d.month, d.day);
        _selectedTime = TimeOfDay(hour: d.hour, minute: d.minute);
      }
      _guessSlidersFromHabitRewards(habitEdit);
    }
    _syncToCalendar = GoogleCalendarService.instance.isSyncEnabled.value;
    _loadEventsForDate(_selectedDate);
  }

  static int _priorityIndexFromTag(TaskTag? tag) {
    if (tag == null) return 1;
    if (tag.type == TagType.high) return 2;
    if (tag.type == TagType.repeat) return 0;
    if (tag.text.contains('Низкий')) return 0;
    return 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Полноэкранный режим открывается через [Navigator.push] без родителя [MainShell] — overlay-тост тогда падает; показываем [SnackBar].
  void _toast(String message, {bool isError = false}) {
    final shell = MainShell.maybeOf(context);
    if (shell != null) {
      shell.showToast(message, isError: isError);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  Future<void> _loadEventsForDate(DateTime date) async {
    if (!GoogleCalendarService.instance.isSyncEnabled.value) return;
    setState(() => _loadingEvents = true);
    try {
      final events = await GoogleCalendarService.instance
          .fetchEventsForDate(date)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _dayEvents = events;
          _loadingEvents = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isModal = !widget.isFullPage;

    Widget content = Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.bgMain,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderDark),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isModal
                          ? Icons.close_rounded
                          : Icons.arrow_back_ios_new_rounded,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _isEditing ? 'Редактировать задачу' : 'Новая задача',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Название задачи'),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Напр. Сходить в спортзал',
                        filled: true,
                        fillColor: AppColors.bgWhite,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.borderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),

                    _label('Описание'),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Добавьте детали или подзадачи...',
                        filled: true,
                        fillColor: AppColors.bgWhite,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.borderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Calendar Date Picker ─────────────────────────────────
                    _label('Дата и время'),
                    _buildCalendarCard(),

                    // ── Google Calendar Events for selected date ─────────────
                    if (GoogleCalendarService.instance.isSyncEnabled.value)
                      _buildDayEventsSection(),

                    ListenableBuilder(
                      listenable: AppStore.instance,
                      builder: (context, _) {
                        if (widget.habitToEdit != null) {
                          return _buildLockedHabitBanner();
                        }
                        return _lockedGoalId != null
                            ? _buildLockedGoalBanner()
                            : _buildGoalDropdown();
                      },
                    ),

                    const SizedBox(height: 20),

                    if (_selectedGoalId != null) ...[
                      _label('Приоритет'),
                      Row(
                        children: List.generate(
                          _priorities.length,
                          (i) => Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _priority = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(
                                    right: i < 2 ? 12 : 0),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                decoration: BoxDecoration(
                                  color: _priority == i
                                      ? AppColors.primaryLight
                                      : AppColors.bgWhite,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _priority == i
                                        ? AppColors.primary
                                        : AppColors.borderDark,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _priorities[i],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: _priority == i
                                          ? AppColors.primaryDark
                                          : AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (_selectedGoalId != null)
                      _buildGoalTaskRewardPreview()
                    else
                      Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Сложность',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.toll_rounded,
                                      color: AppColors.primaryDark,
                                      size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+$_finalXpReward XP',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.paid_rounded,
                                      color: AppColors.yellow,
                                      size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+$_finalCoinReward',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 8,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 20),
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor:
                                  const Color(0xFFDDD6FE),
                              thumbColor: AppColors.primary,
                            ),
                            child: Slider(
                              value: _complexity,
                              min: 1,
                              max: 3,
                              divisions: 2,
                              onChanged: (v) =>
                                  setState(() => _complexity = v),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Легко',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                              Text('Нормально',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                              Text('Эпично',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_selectedGoalId != null)
                            Text(
                              'Награда умножается на приоритет: '
                              '${_priorities[0].toLowerCase()} ×${_priorityMultipliers[0]} · '
                              '${_priorities[1].toLowerCase()} ×${_priorityMultipliers[1]} · '
                              '${_priorities[2].toLowerCase()} ×${_priorityMultipliers[2]}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                height: 1.25,
                              ),
                            )
                          else
                            Text(
                              'Награда зависит от сложности (без приоритета цели).',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Repeat toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.repeat_rounded,
                                color: AppColors.primary, size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Повторять задачу',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        _buildToggle(_repeat, (v) => setState(() => _repeat = v)),
                      ],
                    ),

                    if (_repeat) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(
                          _repeats.length,
                          (i) => Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _repeatIndex = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(
                                    right: i < 2 ? 12 : 0),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  color: _repeatIndex == i
                                      ? AppColors.primary
                                      : AppColors.bgWhite,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _repeatIndex == i
                                        ? AppColors.primary
                                        : AppColors.borderDark,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _repeats[i],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: _repeatIndex == i
                                          ? Colors.white
                                          : AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ── Sync to Calendar toggle ────────────────────────────
                    if (GoogleCalendarService.instance.isSyncEnabled.value) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_month_rounded,
                                  color: AppColors.blue, size: 22),
                              const SizedBox(width: 8),
                              const Text(
                                'Добавить в Google Calendar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          _buildToggle(_syncToCalendar,
                              (v) => setState(() => _syncToCalendar = v)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _createTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: AppColors.primary
                              .withValues(alpha: 0.65),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditing ? 'Сохранить' : 'Создать задачу',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return content;
  }

  Widget _buildGoalTaskRewardPreview() {
    final gid = _selectedGoalId!;
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final n = AppStore.instance.getTasksForGoal(gid).length + 1;
        GoalModel? goal;
        for (final g in AppStore.instance.goals) {
          if (g.id == gid) {
            goal = g;
            break;
          }
        }
        final pool = goal?.xpTaskPool ?? GoalXpRules.defaultTaskPool;
        final completionBonus =
            goal?.xpCompletionBonus ?? GoalXpRules.defaultCompletionBonus;
        final base = GoalXpRules.baseSharePerTask(pool, n);
        final previewTag = TaskTag(
          text: _priorities[_priority],
          type: _priority == 2
              ? TagType.high
              : (_priority == 0 ? TagType.repeat : TagType.medium),
        );
        final xp =
            GoalXpRules.taskXp(pool: pool, taskCount: n, tag: previewTag);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Награда за задачу в цели',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.toll_rounded,
                      color: AppColors.primaryDark, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '+$xp XP при выполнении',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Пул цели — $pool XP на все задачи (хранится в аккаунте). '
                'После сохранения будет $n задач(и): сначала делим поровну (~$base XP за шаг при «среднем» приоритете), '
                'затем множитель «${_priorities[_priority].toLowerCase()}» ×${_priorityMultiplier.toStringAsFixed(2)}. '
                'За эту задачу при выполнении: +$xp XP. '
                'Когда закроете все задачи цели — ещё +$completionBonus XP бонусом.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLockedHabitBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Тип'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Привычка (не привязана к цели)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockedGoalBanner() {
    var goalTitle = 'Цель';
    for (final g in AppStore.instance.goals) {
      if (g.id == _lockedGoalId) {
        goalTitle = g.title;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Цель'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.flag_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  goalTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalDropdown() {
    final goals = AppStore.instance.goals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Привязать к цели'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _selectedGoalId,
              hint: const Text('Без цели'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Без цели'),
                ),
                ...goals.map(
                  (g) => DropdownMenuItem<String?>(
                    value: g.id,
                    child: Text(g.title),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedGoalId = v),
            ),
          ),
        ),
      ],
    );
  }

  // ── Calendar Card with date picker ────────────────────────────────────────
  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          // Month/Year picker header
          CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            onDateChanged: (date) {
              setState(() => _selectedDate = date);
              _loadEventsForDate(date);
            },
          ),
          Divider(height: 1, color: AppColors.borderDark),
          // Time picker row
          InkWell(
            onTap: () => _pickTime(),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.access_time_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Время',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _selectedTime.format(context),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Day Events from Google Calendar ────────────────────────────────────────
  Widget _buildDayEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.event_note_rounded,
                color: AppColors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              'События на ${_formatDate(_selectedDate)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingEvents)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.blue,
                ),
              ),
            ),
          )
        else if (_dayEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded,
                    color: AppColors.success, size: 22),
                const SizedBox(width: 12),
                Text(
                  'Нет событий — день свободен!',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              children: _dayEvents.asMap().entries.map((entry) {
                final i = entry.key;
                final event = entry.value;
                final startTime = event.start?.dateTime;
                final endTime = event.end?.dateTime;
                final timeStr = startTime != null
                    ? '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'
                    : 'Весь день';
                final endStr = endTime != null
                    ? ' — ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}'
                    : '';

                return Column(
                  children: [
                    if (i > 0) Divider(height: 1, color: AppColors.borderDark),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _eventColor(event.colorId),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.summary ?? 'Без названия',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$timeStr$endStr',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Color _eventColor(String? colorId) {
    switch (colorId) {
      case '1': return const Color(0xFF7986CB); // Lavender
      case '2': return const Color(0xFF33B679); // Sage
      case '3': return const Color(0xFF8E24AA); // Grape
      case '4': return const Color(0xFFE67C73); // Flamingo
      case '5': return const Color(0xFFF6BF26); // Banana
      case '6': return const Color(0xFFFF8A65); // Tangerine
      case '7': return const Color(0xFF039BE5); // Peacock
      case '8': return const Color(0xFF616161); // Graphite
      case '9': return const Color(0xFF3F51B5); // Blueberry
      case '10': return const Color(0xFF0B8043); // Basil
      case '11': return const Color(0xFFD50000); // Tomato
      default: return AppColors.blue;
    }
  }

  // ── Toggle widget ─────────────────────────────────────────────────────────
  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : AppColors.borderDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          alignment: value
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Reward from complexity × priority (монеты и XP) ────────────────────────
  /// Множители для уровней приоритета: Низкий / Средний / Высокий
  static const List<double> _priorityMultipliers = [0.82, 1.0, 1.28];

  double get _priorityMultiplier =>
      _priorityMultipliers[_priority.clamp(0, _priorityMultipliers.length - 1)];

  int get _baseXpFromComplexity {
    if (_complexity <= 1) return 10;
    if (_complexity <= 2) return 30;
    return 50;
  }

  int get _baseCoinsFromComplexity {
    if (_complexity <= 1) return 6;
    if (_complexity <= 2) return 18;
    return 32;
  }

  int get _finalXpReward => math.max(
        5,
        (_baseXpFromComplexity * _priorityMultiplier).round(),
      );

  int get _finalCoinReward => math.max(
        0,
        (_baseCoinsFromComplexity * _priorityMultiplier).round(),
      );

  /// Подобрать ползунки по сохранённым наградам при открытии редактора привычки.
  void _guessSlidersFromHabitRewards(HabitModel h) {
    if (h.isQuickTask) {
      _priority = 1;
      _complexity = 2;
      return;
    }
    final targetXp = h.xpReward;
    var bestDiff = 1 << 30;
    var bestP = 1;
    var bestC = 2.0;
    for (final c in [1.0, 2.0, 3.0]) {
      final base = c <= 1 ? 10 : (c <= 2 ? 30 : 50);
      for (var p = 0; p < 3; p++) {
        final mult = _priorityMultipliers[p];
        final xp = math.max(5, (base * mult).round());
        final d = (xp - targetXp).abs();
        if (d < bestDiff) {
          bestDiff = d;
          bestP = p;
          bestC = c;
        }
      }
    }
    _priority = bestP;
    _complexity = bestC;
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  /// Ограничиваем ожидание Firestore: при «мертвой» сети эмулятора иначе UI зависает без ответа.
  static const Duration _firestoreWait = Duration(seconds: 45);

  Future<bool> _awaitFirestoreVoid(Future<void> future) async {
    try {
      await future.timeout(_firestoreWait);
      return true;
    } on TimeoutException {
      if (mounted) {
        _toast(
          'Облако не ответило за ${_firestoreWait.inSeconds} с. '
          'Проверьте интернет; на эмуляторе: Extended Controls → Cellular/Wi‑Fi или Cold Boot.',
          isError: true,
        );
      }
      return false;
    } on ArgumentError catch (e) {
      if (mounted) {
        _toast(e.message ?? 'Проверьте данные', isError: true);
      }
      return false;
    } catch (e, st) {
      debugPrint('Firestore save: $e\n$st');
      if (mounted) {
        final msg = e.toString();
        _toast(
          msg.length > 160 ? '${msg.substring(0, 160)}…' : msg,
          isError: true,
        );
      }
      return false;
    }
  }

  Future<HabitModel?> _awaitFirestoreHabit(Future<HabitModel> future) async {
    try {
      return await future.timeout(_firestoreWait);
    } on TimeoutException {
      if (mounted) {
        _toast(
          'Облако не ответило за ${_firestoreWait.inSeconds} с. '
          'Проверьте интернет или запустите на реальном устройстве.',
          isError: true,
        );
      }
      return null;
    } on ArgumentError catch (e) {
      if (mounted) {
        _toast(e.message ?? 'Проверьте данные', isError: true);
      }
      return null;
    } catch (e, st) {
      debugPrint('Firestore habit save: $e\n$st');
      if (mounted) {
        final msg = e.toString();
        _toast(
          msg.length > 160 ? '${msg.substring(0, 160)}…' : msg,
          isError: true,
        );
      }
      return null;
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _createTask() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _toast('Введите название задачи', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.habitToEdit != null) {
        try {
          await _updateHabitTask(widget.habitToEdit!);
        } catch (e) {
          if (mounted) _toast('Ошибка сохранения', isError: true);
        }
        return;
      }

      if (widget.taskToEdit != null) {
        try {
          await _updateGoalTask(widget.taskToEdit!, title);
        } catch (e) {
          if (mounted) _toast('Ошибка сохранения', isError: true);
        }
        return;
      }

      final forGoal =
          _selectedGoalId != null && _selectedGoalId!.trim().isNotEmpty;

      try {
        if (forGoal) {
          await _createGoalTask(_selectedGoalId!, title);
        } else {
          await _createHabitTask(title);
        }
      } catch (e) {
        if (mounted) _toast('Ошибка создания задачи', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateGoalTask(TaskModel old, String title) async {
    if (old.completed) {
      if (!mounted) return;
      _toast(
        'Завершённую задачу нельзя редактировать',
        isError: true,
      );
      return;
    }
    final goalId = old.goalId;
    if (goalId == null || goalId.isEmpty) {
      if (!mounted) return;
      _toast(
        'Редактирование доступно только для задач целей',
        isError: true,
      );
      return;
    }

    final store = AppStore.instance;
    final matching = store.goals.where((g) => g.id == goalId);
    if (matching.isEmpty) {
      if (!mounted) return;
      _toast('Цель не найдена', isError: true);
      return;
    }
    final goal = matching.first;

    final currentTasks = store.getTasksForGoal(goalId);
    final n = currentTasks.isEmpty ? 1 : currentTasks.length;
    final pool = goal.xpTaskPool;
    final xpReward = GoalXpRules.taskXp(
      pool: pool,
      taskCount: n,
      tag: TaskTag(
        text: _priorities[_priority],
        type: _priority == 2
            ? TagType.high
            : (_priority == 0 ? TagType.repeat : TagType.medium),
      ),
    );

    final desc = _descController.text.trim();
    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final updated = old.copyWith(
      title: title,
      subtitle: desc.isEmpty ? 'Цель: ${goal.title}' : desc,
      scheduledAt: scheduledAt,
      reward: xpReward,
      isXp: true,
      tag: TaskTag(
        text: _priorities[_priority],
        type: _priority == 2
            ? TagType.high
            : (_priority == 0 ? TagType.repeat : TagType.medium),
      ),
    );

    final ok = await _awaitFirestoreVoid(store.updateTask(updated));
    if (!ok || !mounted) return;

    _toast('Изменения сохранены');
    _afterTaskCreatedSuccess();
  }

  Future<void> _updateHabitTask(HabitModel old) async {
    if (old.isDoneForLocalDay(DateTime.now())) {
      if (!mounted) return;
      _toast(
        'Завершённую задачу нельзя редактировать',
        isError: true,
      );
      return;
    }
    final hid = old.id;
    if (hid == null || hid.isEmpty) {
      if (!mounted) return;
      _toast('Ошибка: нет id задачи', isError: true);
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      _toast('Введите название задачи', isError: true);
      return;
    }

    final deadline = _habitDeadlineFromPicker();

    final updated = old.copyWith(
      title: title,
      notes: _descController.text.trim(),
      deadline: deadline,
      xpReward: _finalXpReward,
      coinReward: _finalCoinReward,
      isQuickTask: false,
    );

    final ok = await _awaitFirestoreVoid(_habitService.updateHabit(updated));
    if (!ok || !mounted) return;

    // Не блокируем UI ожиданием Calendar API (на эмуляторе часто зависает DNS/SSL).
    _scheduleBackgroundHabitCalendarSync(updated);

    if (!mounted) return;
    _toast('Изменения сохранены');
    _afterTaskCreatedSuccess();
  }

  /// Синхронизация с календарём в фоне + таймаут; учитывает «Добавить в Google Calendar».
  void _scheduleBackgroundHabitCalendarSync(HabitModel habitAfterFirestore) {
    if (!_syncToCalendar ||
        !GoogleCalendarService.instance.isSyncEnabled.value) {
      return;
    }
    final snapshot = habitAfterFirestore;
    Future.microtask(() async {
      try {
        final eventId = await GoogleCalendarService.instance
            .syncHabitToCalendar(snapshot)
            .timeout(const Duration(seconds: 25));
        if (eventId != null &&
            eventId.isNotEmpty &&
            eventId != snapshot.calendarEventId) {
          await _habitService.updateHabit(
            snapshot.copyWith(calendarEventId: eventId),
          );
        }
      } catch (e, st) {
        debugPrint('Habit calendar sync: $e\n$st');
      }
    });
  }

  Future<void> _createGoalTask(String goalId, String title) async {
    final store = AppStore.instance;
    final matching = store.goals.where((g) => g.id == goalId);
    if (matching.isEmpty) {
      if (!mounted) return;
      _toast('Цель не найдена', isError: true);
      return;
    }
    final goal = matching.first;

    final currentTasks = store.getTasksForGoal(goalId);
    final newTotal = currentTasks.length + 1;
    final pool = goal.xpTaskPool;
    final prioTag = TaskTag(
      text: _priorities[_priority],
      type: _priority == 2
          ? TagType.high
          : (_priority == 0 ? TagType.repeat : TagType.medium),
    );
    final xpReward =
        GoalXpRules.taskXp(pool: pool, taskCount: newTotal, tag: prioTag);

    final desc = _descController.text.trim();
    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final task = TaskModel(
      id:
          'task_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(99999)}',
      title: title,
      subtitle: desc.isEmpty ? 'Цель: ${goal.title}' : desc,
      goalId: goalId,
      scheduledAt: scheduledAt,
      reward: xpReward,
      isXp: true,
      tag: prioTag,
    );

    final ok = await _awaitFirestoreVoid(store.addTask(task));
    if (!ok || !mounted) return;

    _toast('Задача добавлена в цель!');
    _afterTaskCreatedSuccess();
  }

  Future<void> _createHabitTask(String title) async {
    final deadline = _habitDeadlineFromPicker();

    final habit = HabitModel(
      title: title,
      completed: false,
      createdAt: DateTime.now(),
      isQuickTask: false,
      xpReward: _finalXpReward,
      coinReward: _finalCoinReward,
      deadline: deadline,
      notes: _descController.text.trim(),
    );

    final saved = await _awaitFirestoreHabit(_habitService.addHabit(habit));
    if (saved == null || !mounted) return;

    _scheduleBackgroundHabitCalendarSync(saved);

    if (!mounted) return;
    _toast('Задача успешно создана!');
    _afterTaskCreatedSuccess();
  }

  void _afterTaskCreatedSuccess() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (widget.isFullPage) {
        Navigator.of(context).pop();
      } else {
        _titleController.clear();
        _descController.clear();
        setState(() {
          _selectedDate = DateTime.now();
          _selectedTime = TimeOfDay.now();
          _priority = 1;
          _complexity = 2;
          _repeat = false;
          if (widget.initialGoalId == null &&
              widget.taskToEdit == null &&
              widget.habitToEdit == null) {
            _selectedGoalId = null;
          }
        });
        MainShell.maybeOf(context)?.setIndex(0);
      }
    });
  }

  /// Если выбранное время уже в прошлом, задача сразу попадала в «Просрочено» с нерабочим чекбоксом.
  DateTime _habitDeadlineFromPicker() {
    final proposed = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    return _clampHabitDeadlineToFuture(proposed, _selectedDate);
  }

  static DateTime _clampHabitDeadlineToFuture(DateTime proposed, DateTime dayDate) {
    final now = DateTime.now();
    if (proposed.isAfter(now)) return proposed;
    final endOfDay = DateTime(
      dayDate.year,
      dayDate.month,
      dayDate.day,
      23,
      59,
      59,
    );
    if (endOfDay.isAfter(now)) return endOfDay;
    return now.add(const Duration(minutes: 1));
  }

  String _formatDate(DateTime date) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      );
}
