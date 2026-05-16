
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SubjectPage extends StatefulWidget {
  final Map<String, dynamic> subject;

  const SubjectPage({super.key, required this.subject});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  String? selectionType; // "current" или "grade"

  String rk1Mode = "average"; // average | fixed
  int rk1FixedCount = 5;
  bool formulaEnabled = false;




  List<Map<String, dynamic>> currentScores = [];

  Map<String, Map<String, dynamic>?> grades = {
    'rk1': null,
    'rk2': null,
    'exam': null,
    'rating': null,
  };

  // Для режима множественного выбора
  Set<int> selectedIndexes = {};
  Set<String> selectedGradeKeys = {}; // для rk1, rk2, exam, rating
  bool isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    setState(() => isLoading = true);
    try {
final settingsRes = await supabase
    .from('subject_settings')
    .select()
    .eq('subject_id', widget.subject['id'])
    .limit(1);

 if (settingsRes != null && settingsRes.isNotEmpty) {
  final settings = settingsRes[0];

  formulaEnabled = settings['formula_enabled'] ?? false;
  rk1Mode = settings['rk1_mode'] ?? "average";
  rk1FixedCount = settings['rk1_fixed_count'] ?? 5;
}
} catch (e) {
  print("Settings load error: $e");
}

    try {
      final res = await supabase
          .from('grades')
          .select()
          .eq('subject_id', widget.subject['id']);

      final List<Map<String, dynamic>> gradesRes =
          (res as List).cast<Map<String, dynamic>>();

      currentScores.clear();
      grades = {'rk1': null, 'rk2': null, 'exam': null, 'rating': null};

      for (var g in gradesRes) {
        final category = g['category'] as String;
        final score = (g['score'] as num).toDouble();
        final comment = g['comment'] ?? '';
        final dateStr = g['date'] ?? DateTime.now().toIso8601String();
        final date = DateTime.tryParse(dateStr);

        if (category == 'current') {
          currentScores.add({'id': g['id'], 'score': score, 'date': date, 'comment': comment});
        } else if (category == 'rk1' || category == 'rk2' || category == 'exam') {
          grades[category] = {
            'score': score,
            'comment': comment,
            'date': date,
          };
        }
      }

      // Сортировка по дате
      currentScores.sort((a, b) {
        final dateA = a['date'] as DateTime?;
        final dateB = b['date'] as DateTime?;
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });
      //// 
      final rk1Value = calculateRK1();

      grades['rk1'] = {
        'score': rk1Value,
        'comment': 'auto',
        'date': DateTime.now(),
      };
      // Расчет рейтинга
      if (grades['rk1']?['score'] != null &&
          grades['rk2']?['score'] != null &&
          grades['exam']?['score'] != null) {
        final rk1 = grades['rk1']!['score'];
        final rk2 = grades['rk2']!['score'];
        final exam = grades['exam']!['score'];
        grades['rating'] = {
          'score': ((rk1 + rk2) / 2) * 0.6 + exam * 0.4,
          'comment': '',
          'date': DateTime.now(),
        };
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка загрузки оценок: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

Future<void> saveSettings() async {
  await supabase.from('subject_settings').upsert(
    {
      'subject_id': widget.subject['id'],
      'formula_enabled': formulaEnabled,
      'rk1_mode': rk1Mode,
      'rk1_fixed_count': rk1FixedCount,
    },
    onConflict: 'subject_id',
  );
}
  Future<void> _addOrEditScore(String category, {int? currentIndex, bool isEdit = false}) async {
    final scoreController = TextEditingController();
    final commentController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    if (category == 'current' && isEdit && currentIndex != null) {
      final scoreMap = currentScores[currentIndex];
      scoreController.text = scoreMap['score'].toString();
      commentController.text = scoreMap['comment'] ?? '';
      selectedDate = scoreMap['date'] ?? DateTime.now();
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(
              isEdit ? 'Измените оценку' : 'Введите оценку',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF762640)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: scoreController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Оценка (0–100)'),
                ),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(labelText: 'Комментарий'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Дата: ${DateFormat('dd.MM.yyyy').format(selectedDate)}'),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateSB(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF762640),
                ),
                onPressed: () async {
                  final val = double.tryParse(scoreController.text.trim());
                  if (val == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите корректное число!')),
                    );
                    return;
                  }
                  if (val < 0 || val > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Оценка должна быть от 0 до 100')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  setState(() => isLoading = true);
                  try {
                    final data = {
                      'subject_id': widget.subject['id'],
                      'category': category,
                      'score': val,
                      'comment': commentController.text.trim(),
                      'date': selectedDate.toIso8601String(),
                    };

                    if (category == 'current') {
                      if (isEdit && currentIndex != null) {
                        final id = currentScores[currentIndex]['id'];
                        if (id != null) {
                          await supabase.from('grades').update(data).eq('id', id);
                        } else {
                          await supabase.from('grades').insert(data);
                        }
                      } else {
                        await supabase.from('grades').insert(data);
                      }
                    } else {
                      final exists = await supabase
                          .from('grades')
                          .select()
                          .eq('subject_id', widget.subject['id'])
                          .eq('category', category);

                      if ((exists as List).isEmpty) {
                        await supabase.from('grades').insert(data);
                      } else {
                        await supabase
                            .from('grades')
                            .update(data)
                            .eq('subject_id', widget.subject['id'])
                            .eq('category', category);
                      }
                    }
                    await _loadScores();
                  } catch (e) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
                child: const Text(
                  'Сохранить',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  ///ФУНКЦИЯ РАСЧЁТА RK1

  double? calculateRK1() {
  if (!formulaEnabled) return null;

  if (currentScores.isEmpty) return null;

  double sum = 0;
  for (var s in currentScores) {
    sum += s['score'];
  }

  if (rk1Mode == "average") {
    return sum / currentScores.length;
  }

  if (rk1Mode == "fixed") {
    return sum / rk1FixedCount;
  }

  return null;
}

void _recalculateRK1() {
  final rk1Value = calculateRK1();

  grades['rk1'] = {
    'score': rk1Value,
    'comment': 'auto',
    'date': DateTime.now(),
  };
}
  Color _getBorderColor(double score) {
    if (score >= 90) return const Color.fromARGB(255, 94, 187, 97);
    if (score >= 70) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  Widget _buildCurrentScores() {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...currentScores.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final score = s['score'] as double;
              bool isSelected = selectedIndexes.contains(idx);

              return GestureDetector(
                onLongPress: () {
                  setState(() {
                    isSelectionMode = true;
                    selectionType = "current"; // запоминаем тип
                    selectedIndexes.add(idx);
                  });
                },
                onTap: () {
                  if (isSelectionMode) {
                    // если тип выбора не совпадает — не даём выбрать
                    if (selectionType != "current") return;

                    setState(() {
                      if (isSelected) {
                        selectedIndexes.remove(idx);
                        if (selectedIndexes.isEmpty) {
                          isSelectionMode = false;
                          selectionType = null; // сбрасываем тип
                        }
                      } else {
                        selectedIndexes.add(idx);
                      }
                    });
                  } else {
                    _addOrEditScore('current', isEdit: true, currentIndex: idx);
                  }
                },

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected ? _getBorderColor(score) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _getBorderColor(score), // всегда видна
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _getBorderColor(score).withOpacity(0.3),
                              offset: const Offset(0, 3),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      begin: _getBorderColor(score),
                      end: isSelected ? Colors.white : _getBorderColor(score),
                    ),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, color, child) {
                      return Text(
                        score.toStringAsFixed(0),
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),

              );
            }
          ),
            GestureDetector(
              onTap: () => _addOrEditScore('current'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                ),
                child: const Icon(Icons.add, color: Color(0xFFA1A1A1)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleScoreRow(String title, String category) {
  final data = grades[category];
  final val = data?['score'] as double?;
  bool isLocked = (category == 'rk2' && grades['rk1'] == null) ||
      (category == 'exam' &&
          (grades['rk1'] == null || grades['rk2'] == null));
  bool isAuto = category == 'rk1' && formulaEnabled;
  

  // Если категория заблокирована — показываем замок
  if (isLocked) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => const AlertDialog(
              title: Center(
                child: Text(
                  '🔒 Заблокировано',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF762640)),
                ),
              ),
              content: Text(
                'Вы можете добавить сюда оценку только после предыдущих этапов.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: const Icon(Icons.lock, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  if (val != null) {
    bool isSelected = selectedGradeKeys.contains(category);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onLongPress: () {
            setState(() {
              isSelectionMode = true;
              selectionType = "grade"; // выбор из рубежных
              selectedGradeKeys.add(category);
            });
          },
          onTap: () {
            if (isSelectionMode) {
              // если тип выбора другой — игнорируем
              if (selectionType != "grade") return;

              setState(() {
                if (isSelected) {
                  selectedGradeKeys.remove(category);
                  if (selectedGradeKeys.isEmpty) {
                    isSelectionMode = false;
                    selectionType = null; // сброс
                  }
                } else {
                  selectedGradeKeys.add(category);
                }
              });
            } else {
              _addOrEditScore(category, isEdit: true);
            }
          },

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _getBorderColor(val)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _getBorderColor(val), width: 2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _getBorderColor(val).withOpacity(0.3),
                        offset: const Offset(0, 3),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                begin: _getBorderColor(val),
                end: isSelected ? Colors.white : _getBorderColor(val),
              ),
              duration: const Duration(milliseconds: 300),
              builder: (context, color, child) {
                return Text(
                  val == null ? "—" : val.toStringAsFixed(0),
                  style: TextStyle(
                    color: val == null ? Colors.grey : _getBorderColor(val),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Если оценки нет — кнопка добавления
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      GestureDetector(
        onTap: () => _addOrEditScore(category),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: const Icon(Icons.add, color: Color(0xFFA1A1A1)),
        ),
      ),
    ],
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        
        leadingWidth: 50,
        titleSpacing: 0,
        title: Text(widget.subject['name'],
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 20)),
        backgroundColor: const Color(0xFF762640),
        actions: [
          IconButton(
  icon: const Icon(Icons.functions),
  onPressed: () {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text("Formula settings"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text("Activate formula"),
                    value: formulaEnabled,
                    onChanged: (val) async {
                      setStateSB(() => formulaEnabled = val);
                      setState(() => formulaEnabled = val);

                      await saveSettings();
                      await _loadScores();
                      setState(() {
    _recalculateRK1();
  });
                    },
                  ),

                  const SizedBox(height: 10),

                  DropdownButton<String>(
                    value: rk1Mode,
                    items: const [
                      DropdownMenuItem(
                        value: "average",
                        child: Text("Average (sum/count)"),
                      ),
                      DropdownMenuItem(
                        value: "fixed",
                        child: Text("Fixed divisor"),
                      ),
                    ],
                    onChanged: (val) async {
                      if (val == null) return;

                      setStateSB(() => rk1Mode = val);
                      setState(() => rk1Mode = val);
                      await saveSettings();
await _loadScores();
setState(() {
    _recalculateRK1();
  });
                    },
                  ),

                  if (rk1Mode == "fixed")
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Expected count",
                      ),
                      onChanged: (val) async {
                        rk1FixedCount = int.tryParse(val) ?? 5;
                        await saveSettings();
await _loadScores();
setState(() {
    _recalculateRK1();
  });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  },
),
          if (isSelectionMode)
            IconButton(
             icon: const Padding(
              padding: EdgeInsets.only(right: 10, top: 2),
              child: Icon(Icons.delete_rounded, size: 26,),
            ),
              onPressed: () async {
                final isSingle = selectedIndexes.length == 1;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Center(
                      child: Text(
                        isSingle ? 'Удалить оценку?' : 'Удалить оценки?', style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF762640)),
                        textAlign: TextAlign.center,
                        
                      ),
                    ),
                    content: Text(
                      isSingle
                          ? 'Вы уверены, что хотите удалить эту оценку? Это действие нельзя будет отменить.'
                          : 'Вы уверены, что хотите удалить выбранные оценки? Это действие нельзя будет отменить.',
                      textAlign: TextAlign.center,
                    ),
                    actionsAlignment: MainAxisAlignment.center, // кнопки по центру
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF762640)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Удалить', style: TextStyle(color: Colors.white),),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                setState(() => isLoading = true);
                try {
                  for (int idx in selectedIndexes) {
                    final id = currentScores[idx]['id'];
                    if (id != null) {
                      await supabase.from('grades').delete().eq('id', id);
                    }
                  }
                  selectedIndexes.clear();
                  isSelectionMode = false;
                  await _loadScores();
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
                } finally {
                  setState(() => isLoading = false);
                }
              },
            ),
        ],
      ),

      backgroundColor: const Color(0xFFFFFEFD),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Средние текущие:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    _buildCurrentScores(),
                    const SizedBox(height: 24),
                    _buildSingleScoreRow('РК1', 'rk1'),
                    const SizedBox(height: 12),
                    _buildSingleScoreRow('РК2', 'rk2'),
                    const SizedBox(height: 12),
                    _buildSingleScoreRow('Экзамен', 'exam'),
                    const SizedBox(height: 24),
                    if (grades['rating']?['score'] != null)
                      Text(
                        'Рейтинг: ${grades['rating']!['score'].toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}