import 'package:flutter/material.dart';

import '../models/habit_model.dart';
import '../services/habit_service.dart';
import '../theme/app_colors.dart';

/// Создание и редактирование повторяющейся привычки (`users/{uid}/habits`).
class CreateHabitScreen extends StatefulWidget {
  const CreateHabitScreen({super.key, this.habitToEdit});

  final HabitModel? habitToEdit;

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  final _habitService = HabitService();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _everyDay = true;
  final Set<int> _weekdays = {};
  double _xp = 15;
  bool _saving = false;
  final List<String> _times = [];

  static const _dayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  bool get _isEdit => widget.habitToEdit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.habitToEdit;
    if (e != null) {
      _title.text = e.title;
      _notes.text = e.notes;
      _xp = e.xpReward.toDouble().clamp(5, 100);
      _times.clear();
      _times.addAll(e.reminderTimes);
      if (e.repeatWeekdays.isEmpty) {
        _everyDay = true;
      } else {
        _everyDay = false;
        _weekdays.clear();
        _weekdays.addAll(e.repeatWeekdays);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<int> _repeatWeekdays() {
    if (_everyDay) return const [];
    final list = _weekdays.toList()..sort();
    return list;
  }

  List<String> _sortedUniqueTimes() {
    final set = <String>{};
    for (final t in _times) {
      final n = HabitModel.normalizeTimeHm(t);
      if (n != null) set.add(n);
    }
    final out = set.toList()..sort();
    return out;
  }

  Future<void> _pickTime() async {
    final initial = TimeOfDay.now();
    final t = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (t == null || !mounted) return;
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (!_times.contains(hm)) _times.add(hm);
      _times.sort();
    });
  }

  void _removeTime(String hm) {
    setState(() => _times.remove(hm));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_everyDay && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Выберите хотя бы один день или «Каждый день»'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
      return;
    }

    final sortedTimes = _sortedUniqueTimes();
    final old = widget.habitToEdit;
    final oldSet = old?.reminderTimes.toSet() ?? {};
    final newSet = sortedTimes.toSet();
    final timesChanged = old != null &&
        (oldSet.length != newSet.length ||
            oldSet.difference(newSet).isNotEmpty ||
            newSet.difference(oldSet).isNotEmpty);

    setState(() => _saving = true);
    try {
      if (old != null && old.id != null && old.id!.isNotEmpty) {
        var next = old.copyWith(
          title: _title.text.trim(),
          notes: _notes.text.trim(),
          repeatWeekdays: _repeatWeekdays(),
          xpReward: _xp.round().clamp(5, 100),
          reminderTimes: sortedTimes,
          clearSlotsProgress: timesChanged ||
              _setChanged(old.repeatWeekdays, _repeatWeekdays()),
        );
        await _habitService.updateHabit(next);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Привычка обновлена'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      } else {
        final habit = HabitModel(
          title: _title.text.trim(),
          completed: false,
          createdAt: DateTime.now(),
          isQuickTask: false,
          isRecurring: true,
          repeatWeekdays: _repeatWeekdays(),
          reminderTimes: sortedTimes,
          xpReward: _xp.round().clamp(5, 100),
          coinReward: 0,
          notes: _notes.text.trim(),
        );
        await _habitService.addHabit(habit);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Привычка добавлена'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _setChanged(List<int> a, List<int> b) {
    if (a.length != b.length) return true;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                  ),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Редактировать привычку' : 'Новая привычка',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _title,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Название',
                          filled: true,
                          fillColor: AppColors.bgWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Введите название';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Время напоминаний',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Несколько времён в день (например, лекарства). Пусто — одна отметка на день.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickTime,
                        icon: Icon(Icons.schedule_rounded, color: AppColors.primary),
                        label: Text(
                          'Добавить время',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 14),
                          side: BorderSide(color: AppColors.borderDark),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      if (_times.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _sortedUniqueTimes()
                              .map(
                                (hm) => Chip(
                                  label: Text(hm),
                                  onDeleted: _saving ? null : () => _removeTime(hm),
                                  deleteIconColor: AppColors.textMuted,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Повторение',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Каждый день'),
                            selected: _everyDay,
                            onSelected: (v) {
                              setState(() {
                                _everyDay = v;
                                if (v) _weekdays.clear();
                              });
                            },
                            selectedColor: AppColors.primaryLight,
                            checkmarkColor: AppColors.primary,
                          ),
                          FilterChip(
                            label: const Text('По дням недели'),
                            selected: !_everyDay,
                            onSelected: (v) {
                              setState(() {
                                _everyDay = !v;
                                if (_everyDay) _weekdays.clear();
                              });
                            },
                            selectedColor: AppColors.primaryLight,
                            checkmarkColor: AppColors.primary,
                          ),
                        ],
                      ),
                      if (!_everyDay) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(7, (i) {
                            final wd = i + 1;
                            final sel = _weekdays.contains(wd);
                            return FilterChip(
                              label: Text(_dayLabels[i]),
                              selected: sel,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _weekdays.add(wd);
                                  } else {
                                    _weekdays.remove(wd);
                                  }
                                });
                              },
                              selectedColor: AppColors.primaryLight,
                              checkmarkColor: AppColors.primary,
                            );
                          }),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Награда: ${_xp.round()} XP за все слоты дня',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'XP делится между отметками по времени.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Slider(
                        value: _xp,
                        min: 5,
                        max: 50,
                        divisions: 9,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _xp = v),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notes,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: 'Заметка (необязательно)',
                          filled: true,
                          fillColor: AppColors.bgWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isEdit ? 'Сохранить' : 'Сохранить привычку',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
