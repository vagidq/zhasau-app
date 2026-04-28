import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import '../theme/app_colors.dart';
import '../services/google_calendar_service.dart';
import '../services/habit_service.dart';
import '../models/habit_model.dart';
import '../models/app_store.dart';
import 'main_shell.dart';

class CreateTaskScreen extends StatefulWidget {
  final bool isFullPage;
  const CreateTaskScreen({super.key, this.isFullPage = false});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  int _priority = 1; // 0=Low, 1=Med, 2=High
  double _complexity = 2;
  bool _repeat = false;
  int _repeatIndex = 0;
  bool _syncToCalendar = true;

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

  @override
  void initState() {
    super.initState();
    _syncToCalendar = GoogleCalendarService.instance.isSyncEnabled.value;
    _loadEventsForDate(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsForDate(DateTime date) async {
    if (!GoogleCalendarService.instance.isSyncEnabled.value) return;
    setState(() => _loadingEvents = true);
    try {
      final events = await GoogleCalendarService.instance.fetchEventsForDate(date);
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
                                    '+$_complexityReward XP',
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
                        ],
                      ),
                    ),

                    _label('Привязать к цели'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bgWhite,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: 'Без цели',
                          items: [
                            const DropdownMenuItem(
                                value: 'Без цели',
                                child: Text('Без цели')),
                            ...AppStore.instance.goals.map((g) =>
                              DropdownMenuItem(
                                  value: g.title,
                                  child: Text(g.title)),
                            ),
                          ],
                          onChanged: (_) {},
                        ),
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
                        onPressed: _createTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('Создать задачу',
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

  // ── Computed values ────────────────────────────────────────────────────────
  int get _complexityReward {
    if (_complexity <= 1) return 10;
    if (_complexity <= 2) return 30;
    return 50;
  }

  // ── Actions ────────────────────────────────────────────────────────────────
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
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      MainShell.of(context).showToast('Введите название задачи', isError: true);
      return;
    }

    final deadline = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      final habit = HabitModel(
        title: title,
        completed: false,
        createdAt: DateTime.now(),
        isQuickTask: false,
        xpReward: _complexityReward,
        deadline: deadline,
      );

      await _habitService.addHabit(habit);

      // Sync to Google Calendar if enabled
      if (_syncToCalendar && GoogleCalendarService.instance.isSyncEnabled.value) {
        await GoogleCalendarService.instance.syncHabitToCalendar(habit);
      }

      if (!mounted) return;
      MainShell.of(context).showToast('Задача успешно создана!');
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
          });
          MainShell.of(context).setIndex(0);
        }
      });
    } catch (e) {
      if (!mounted) return;
      MainShell.of(context).showToast('Ошибка создания задачи', isError: true);
    }
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
