import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_colors.dart';
import '../models/app_store.dart';
import '../models/goal_model.dart';
import '../models/habit_model.dart';
import '../models/task_model.dart';
import '../services/habit_service.dart';
import '../utils/firestore_ids.dart';

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  int _selectedCategory = 0;
  int _selectedRewardPreset = 1;
  bool _isCreating = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final DateTime _startDate = DateTime.now();
  DateTime? _deadline;

  // Inline task list
  final List<TextEditingController> _taskControllers = [];
  static const Duration _cloudWait = Duration(seconds: 25);

  final HabitService _habitService = HabitService();
  final Set<String> _selectedExistingHabitIds = <String>{};
  final List<({String label, int xp, int coins})> _goalRewardPresets = const [
    (label: 'Базовая', xp: 100, coins: 30),
    (label: 'Стандарт', xp: 150, coins: 50),
    (label: 'Сильная', xp: 250, coins: 90),
    (label: 'Максимум', xp: 400, coins: 150),
  ];

  final _categories = ['Здоровье', 'Образование', 'Карьера', 'Хобби'];
  final _categoryIcons = [
    Icons.fitness_center_rounded,
    Icons.menu_book_rounded,
    Icons.work_rounded,
    Icons.palette_rounded,
  ];
  final _categoryColors = [
    AppColors.warning,
    AppColors.blue,
    AppColors.success,
    AppColors.primary,
  ];
  final _categoryBgs = [
    AppColors.warningLight,
    AppColors.blueLight,
    AppColors.successLight,
    AppColors.primaryLight,
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// Плашка награды: иконка + число (XP или монеты).
  Widget _goalRewardPill({
    required IconData icon,
    required int amount,
    required Color accent,
    bool compact = false,
  }) {
    final iconSize = compact ? 17.0 : 20.0;
    final fontSize = compact ? 14.0 : 16.0;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 7)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: pad,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, size: iconSize, color: accent),
            SizedBox(width: compact ? 5 : 8),
            Flexible(
              child: Text(
                '+$amount',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.bgWhite,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _addTaskField() {
    setState(() => _taskControllers.add(TextEditingController()));
  }

  void _removeTaskField(int index) {
    _taskControllers[index].dispose();
    setState(() => _taskControllers.removeAt(index));
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? Colors.red[700] : AppColors.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _createGoal() async {
    if (_isCreating) return;

    if (_titleController.text.trim().isEmpty) {
      _showSnack('Введите название цели', isError: true);
      return;
    }

    const colorMap = {
      0: GoalColor.warning,   // Здоровье
      1: GoalColor.blue,      // Образование
      2: GoalColor.success,   // Карьера
      3: GoalColor.warning,   // Хобби
    };

    final taskTitles = _taskControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    List<HabitModel> existingHabits = const <HabitModel>[];
    if (_selectedExistingHabitIds.isNotEmpty) {
      try {
        final all = await _habitService.getAllHabitsOnce().timeout(_cloudWait);
        existingHabits = all
            .where((h) =>
                h.id != null && _selectedExistingHabitIds.contains(h.id))
            .toList(growable: false);
      } catch (e, st) {
        debugPrint('Read existing habits before goal create: $e\n$st');
      }
    }

    final totalTasks = taskTitles.length + existingHabits.length;
    final preset = _goalRewardPresets[_selectedRewardPreset];
    final goalRewardXp = preset.xp;
    final goalRewardCoins = preset.coins;

    if (totalTasks == 0) {
      _showSnack('Добавьте хотя бы одну задачу к цели', isError: true);
      return;
    }

    setState(() => _isCreating = true);
    try {
      final goalTitle = _titleController.text.trim();
      final goalId = makeReadableId('goal', goalTitle);
      final newGoal = GoalModel(
        id: goalId,
        title: goalTitle,
        subtitle: _descriptionController.text.trim(),
        badge: '0/$totalTasks',
        iconName: _categories[_selectedCategory].toLowerCase(),
        color: colorMap[_selectedCategory]!,
        progress: 0,
        tasksLeft: totalTasks,
        deadline: _deadline,
        startDate: _startDate,
        xpCompletionBonus: goalRewardXp,
        coinsCompletionBonus: goalRewardCoins,
      );

      await AppStore.instance.addGoal(newGoal).timeout(_cloudWait);

      final totalSteps = taskTitles.length + existingHabits.length;
      var stepIdx = 0;

      for (int i = 0; i < taskTitles.length; i++) {
        final title = taskTitles[i];
        final task = TaskModel(
          id: makeReadableId('task', title),
          title: title,
          subtitle: _categories[_selectedCategory],
          goalId: goalId,
          reward: 0,
          isXp: true,
          tag: const TaskTag(text: 'Средний', type: TagType.medium),
        );
        stepIdx++;
        final last = stepIdx == totalSteps;
        await AppStore.instance.addTask(
          task,
          rebalanceGoalRewards: last,
        ).timeout(_cloudWait);
      }

      for (final habit in existingHabits) {
        final when = habit.deadline ??
            DateTime.now().add(const Duration(hours: 1));
        final task = TaskModel(
          id: makeReadableId('task', habit.title),
          title: habit.title,
          subtitle: habit.notes.trim().isEmpty
              ? _categories[_selectedCategory]
              : habit.notes.trim(),
          goalId: goalId,
          scheduledAt: when,
          reward: 0,
          isXp: true,
          tag: const TaskTag(text: 'Средний', type: TagType.medium),
        );
        stepIdx++;
        final last = stepIdx == totalSteps;
        await AppStore.instance.addTask(
          task,
          rebalanceGoalRewards: last,
        ).timeout(_cloudWait);

        if (habit.id != null && habit.id!.isNotEmpty) {
          try {
            await _habitService.deleteHabit(habit.id!).timeout(_cloudWait);
          } catch (e, st) {
            debugPrint('Delete attached habit ${habit.id}: $e\n$st');
          }
        }
      }

      if (!mounted) return;
      _showSnack('Цель успешно создана!');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      _showSnack(e.message ?? 'Проверьте данные', isError: true);
    } on TimeoutException {
      if (!mounted) return;
      _showSnack(
        'Сервер долго не отвечает. Проверьте сеть эмулятора (Wi‑Fi/Cellular) и повторите.',
        isError: true,
      );
    } catch (e, st) {
      debugPrint('CreateGoal error: $e\n$st');
      _showSnack('Не удалось создать цель. Проверьте соединение.', isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.bgMain,
                border: Border(bottom: BorderSide(color: AppColors.borderDark)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Новая цель',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Form ────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category
                    _label('Категория'),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.5,
                      children: List.generate(_categories.length, (i) {
                        final selected = _selectedCategory == i;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? _categoryBgs[i] : AppColors.bgWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? _categoryColors[i]
                                    : AppColors.borderDark,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _categoryIcons[i],
                                  color: selected
                                      ? _categoryColors[i]
                                      : AppColors.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _categories[i],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: selected
                                        ? _categoryColors[i]
                                        : AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),

                    // Title
                    _label('Название цели'),
                    _inputField(_titleController, 'Напр. Пробежать марафон'),

                    // Description
                    _label('Описание'),
                    _textAreaField(
                        _descriptionController, 'Опишите вашу цель подробнее...'),

                    // Dates row
                    _label('Даты'),
                    Row(
                      children: [
                        // Start date — readonly
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дата начала',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.bgWhite,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.borderDark),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        color: AppColors.textMuted, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _fmt(_startDate),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Deadline — tappable
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дедлайн',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: _pickDeadline,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgWhite,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _deadline != null
                                          ? AppColors.primary
                                          : AppColors.borderDark,
                                      width: _deadline != null ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.event_rounded,
                                          color: _deadline != null
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _deadline != null
                                            ? _fmt(_deadline!)
                                            : 'Выбрать',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _deadline != null
                                              ? AppColors.textDark
                                              : AppColors.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Motivation card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _categoryBgs[_selectedCategory],
                            _categoryBgs[_selectedCategory].withAlpha(153),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _categoryColors[_selectedCategory].withAlpha(76),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _categoryColors[_selectedCategory].withAlpha(51),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.emoji_events_rounded,
                              color: _categoryColors[_selectedCategory],
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Награда за полное выполнение цели',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _categoryColors[_selectedCategory],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Выполните все задачи цели — тогда начислятся опыт и монеты. '
                                  'Сколько именно, выберите уровнем ниже.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    _label('Уровень награды'),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 10.0;
                        final itemWidth = (constraints.maxWidth - gap) / 2;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: List.generate(_goalRewardPresets.length, (i) {
                            final p = _goalRewardPresets[i];
                            final selected = i == _selectedRewardPreset;
                            return SizedBox(
                              width: itemWidth,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() => _selectedRewardPreset = i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 13,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.primaryLight
                                              .withValues(alpha: 0.45)
                                          : AppColors.bgWhite,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        width: 1.4,
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.borderDark,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              selected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.circle_outlined,
                                              size: 18,
                                              color: selected
                                                  ? AppColors.primary
                                                  : AppColors.textLight,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                p.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: selected
                                                      ? AppColors.primaryDark
                                                      : AppColors.textDark,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _goalRewardPill(
                                                icon: Icons.bolt_rounded,
                                                amount: p.xp,
                                                accent: AppColors.primary,
                                                compact: true,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _goalRewardPill(
                                                icon:
                                                    Icons.monetization_on_rounded,
                                                amount: p.coins,
                                                accent: AppColors.warning,
                                                compact: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),

                    // ── Linked tasks ────────────────────────────────────
                    _label('Задачи к цели'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Новые задачи',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Existing task fields
                          for (int i = 0; i < _taskControllers.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.drag_indicator_rounded,
                                      color: AppColors.textLight, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _taskControllers[i],
                                      decoration: InputDecoration(
                                        hintText: 'Название задачи...',
                                        hintStyle: TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 14),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: AppColors.textDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _removeTaskField(i),
                                    child: Icon(Icons.close_rounded,
                                        color: AppColors.textLight, size: 20),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _addTaskField,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Добавить задачу'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Можно добавить новые задачи или выбрать существующие — '
                            'они станут шагами этой цели.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Existing tasks (habits) section
                    _buildExistingTasksSection(),

                    const SizedBox(height: 28),

                    // Create button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCreating ? null : _createGoal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Создать цель',
                                style: TextStyle(
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
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      );

  Widget _inputField(
        TextEditingController ctrl,
        String hint, {
        TextInputType keyboardType = TextInputType.text,
      }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.bgWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      );

  Widget _buildExistingTasksSection() {
    return StreamBuilder<List<HabitModel>>(
      stream: _habitService.getHabits(),
      builder: (context, snap) {
        final list = (snap.data ?? const <HabitModel>[])
            .where((h) => !h.completed && (h.id != null && h.id!.isNotEmpty))
            .toList(growable: false);
        if (list.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.playlist_add_check_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Существующие задачи',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedExistingHabitIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Выбрано ${_selectedExistingHabitIds.length}',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Отметьте те, что станут шагами цели. Они перенесутся из обычных задач в цель.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < list.length; i++) ...[
                  _existingTaskTile(list[i]),
                  if (i != list.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _existingTaskTile(HabitModel h) {
    final selected = _selectedExistingHabitIds.contains(h.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (selected) {
              _selectedExistingHabitIds.remove(h.id);
            } else {
              _selectedExistingHabitIds.add(h.id!);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryLight.withValues(alpha: 0.45)
                : AppColors.bgMain,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: 1.4,
              color: selected ? AppColors.primary : AppColors.borderDark,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textLight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected
                            ? AppColors.primaryDark
                            : AppColors.textDark,
                      ),
                    ),
                    if (h.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        h.notes.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textAreaField(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.bgWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      );
}
