import 'package:flutter/material.dart';
import '../models/app_store.dart';
import '../models/task_model.dart';
import '../theme/app_colors.dart';
import 'main_shell.dart';

class CreateTaskScreen extends StatefulWidget {
  final bool isFullPage;
  final bool asDraft;
  final String? initialGoalId;
  const CreateTaskScreen({
    super.key,
    this.isFullPage = false,
    this.asDraft = false,
    this.initialGoalId,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  int _priority = 1; // 0=Низкий, 1=Средний, 2=Высокий
  double _complexity = 1; // 1=Легко(10), 2=Нормально(20), 3=Эпично(30)
  bool _repeat = false;
  int _repeatIndex = 0;
  String? _selectedGoalId; // null = без цели

  @override
  void initState() {
    super.initState();
    _selectedGoalId = widget.initialGoalId;
  }

  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  final _priorities = ['Низкий', 'Средний', 'Высокий'];
  final _repeats = ['Ежедневно', 'Еженедельно', 'Ежемесячно'];

  int get _coins {
    return (_priority * 20) + (_complexity.toInt() * 10);
  }

  int get _xp {
    return _coins + 10;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final goals = store.goals;

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
                      widget.isFullPage
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.close_rounded,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Новая задача',
                        style: TextStyle(
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
                          borderSide: BorderSide(color: AppColors.borderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: AppColors.primary, width: 1.5),
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
                          borderSide: BorderSide(color: AppColors.borderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),

                    _label('Приоритет'),
                    Row(
                      children: List.generate(
                        _priorities.length,
                        (i) => Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _priority = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
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
                    // Complexity card
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
                              const Text(
                                'Сложность',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.toll_rounded,
                                      color: AppColors.primaryDark, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+$_coins монет  +$_xp XP',
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
                              inactiveTrackColor: const Color(0xFFDDD6FE),
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
                                      color: AppColors.textMuted, fontSize: 12)),
                              Text('Нормально',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 12)),
                              Text('Эпично',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (!widget.asDraft) ...[
                      _label('Привязать к цели'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.bgWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedGoalId,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Без цели'),
                              ),
                              ...goals.map((g) => DropdownMenuItem<String?>(
                                    value: g.id,
                                    child: Text(g.subtitle.isNotEmpty
                                        ? g.subtitle
                                        : g.title),
                                  )),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedGoalId = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
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
                        GestureDetector(
                          onTap: () =>
                              setState(() => _repeat = !_repeat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 44,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _repeat
                                  ? AppColors.primary
                                  : AppColors.borderDark,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 250),
                              alignment: _repeat
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
                        ),
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
                                margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _repeatIndex == i
                                      ? AppColors.primary
                                      : AppColors.bgWhite,
                                  borderRadius: BorderRadius.circular(20),
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

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _createTask(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text(
                          'Создать задачу',
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

    return content;
  }

  Future<void> _createTask(BuildContext context) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название задачи')),
      );
      return;
    }

    final store = AppStore.instance;
    final priorityLabels = ['Низкий', 'Средний', 'Высокий'];
    final compLabels = {1.0: 'Легко', 2.0: 'Нормально', 3.0: 'Эпично'};

    // Build subtitle: priority label
    final subtitle = priorityLabels[_priority];

    // Tag based on complexity
    final tagTypes = {1.0: TagType.low, 2.0: TagType.medium, 3.0: TagType.high};
    final tag = TaskTag(
      text: compLabels[_complexity] ?? 'Легко',
      type: tagTypes[_complexity] ?? TagType.low,
    );

    final task = TaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subtitle: subtitle,
      goalId: widget.asDraft ? null : _selectedGoalId,
      reward: _coins,
      xpReward: _xp,
      isXp: false,
      tag: tag,
      priority: _priority,
      completed: false,
    );

    if (widget.asDraft) {
      Navigator.of(context).pop(task);
      return;
    }

    try {
      await store.addTask(task);
      if (mounted) {
        if (widget.isFullPage) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Задача успешно создана!')),
           );
           Navigator.of(context).pop();
        } else {
           final shell = MainShell.of(context);
           shell.showToast('Задача успешно создана!');
           Future.delayed(const Duration(milliseconds: 600), () {
             if (mounted) shell.setIndex(0);
           });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
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
