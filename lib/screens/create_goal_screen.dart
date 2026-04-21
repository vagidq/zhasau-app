import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_store.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';
import 'create_task_screen.dart';

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  int _selectedCategory = 0;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final DateTime _startDate = DateTime.now();
  DateTime? _deadline;

  // Draft task list
  final List<TaskModel> _draftTasks = [];

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
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

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

  Future<void> _addTask() async {
    final TaskModel? draft = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateTaskScreen(
          isFullPage: true,
          asDraft: true,
        ),
      ),
    );
    if (draft != null) {
      if (!mounted) return;
      setState(() => _draftTasks.add(draft));
    }
  }

  void _removeTask(int index) {
    setState(() => _draftTasks.removeAt(index));
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

    final goalId = DateTime.now().millisecondsSinceEpoch.toString();

    final newGoal = GoalModel(
      id: goalId,
      title: _titleController.text.trim(),
      subtitle: _descriptionController.text.trim(),
      badge: '0/${_draftTasks.length}',
      iconName: _categories[_selectedCategory].toLowerCase(),
      color: colorMap[_selectedCategory]!,
      progress: 0,
      tasksLeft: _draftTasks.length,
      deadline: _deadline,
      startDate: _startDate,
    );

    try {
      await AppStore.instance.addGoal(newGoal);

      // Create linked tasks via AppStore
      for (int i = 0; i < _draftTasks.length; i++) {
        final draftTask = _draftTasks[i];
        final task = draftTask.copyWith(
          id: '${goalId}_task_${DateTime.now().millisecondsSinceEpoch}_$i',
          goalId: goalId,
        );
        await AppStore.instance.addTask(task);
      }

      if (!mounted) return;
      _showSnack('Цель успешно создана!');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('CreateGoal error: $e\n$st');
      _showSnack('Не удалось создать цель. Проверьте соединение.', isError: true);
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
                                  'Достижение цели = награды!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _categoryColors[_selectedCategory],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'За каждую задачу цели вы получаете XP и монеты',
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
                        children: [
                          // Existing draft tasks
                          for (int i = 0; i < _draftTasks.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.drag_indicator_rounded,
                                      color: AppColors.textLight, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _draftTasks[i].title,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textDark),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _draftTasks[i].subtitle,
                                      style: TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _removeTask(i),
                                    child: Icon(Icons.close_rounded,
                                        color: AppColors.textLight, size: 20),
                                  ),
                                ],
                              ),
                            ),

                          // Add button
                          GestureDetector(
                            onTap: _addTask,
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.add_rounded,
                                      color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Добавить задачу к цели',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Create button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _createGoal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
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

  Widget _inputField(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
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
