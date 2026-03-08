import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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
  bool _repeat = true;
  int _repeatIndex = 0;

  final _priorities = ['Низкий', 'Средний', 'Высокий'];
  final _repeats = ['Ежедневно', 'Еженедельно', 'Ежемесячно'];

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
                    // Date & Time row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Дата'),
                              _iconInput(
                                  Icons.calendar_today_rounded,
                                  '24.05.2024'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Время'),
                              _iconInput(Icons.access_time_rounded, '18:00'),
                            ],
                          ),
                        ),
                      ],
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
                                    '+50 монет',
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
                          items: const [
                            DropdownMenuItem(
                                value: 'Без цели',
                                child: Text('Без цели')),
                            DropdownMenuItem(
                                value: 'Марафон 2024',
                                child: Text('Марафон 2024')),
                            DropdownMenuItem(
                                value: 'Английский B2',
                                child: Text('Английский B2')),
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

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          MainShell.of(context)
                              .showToast('Задача успешно создана!');
                          Future.delayed(const Duration(milliseconds: 600),
                              () {
                            if (mounted) Navigator.of(context).pop();
                          });
                        },
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

  Widget _iconInput(IconData icon, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
}
