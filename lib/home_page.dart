// home_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:grade_tracker/ai_analytics_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';




class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> subjects = [];
  Map<String, double> avgBySubject = {};
  String userName = '';
  String userEmail = '';

  @override
  void initState() {
    super.initState();
    _initUserAndLoad();
  }

  Future<void> _initUserAndLoad() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      userEmail = user.email ?? '';
      userName = (user.userMetadata?['name'] ?? '') as String;
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);
    try {
      // Загрузка предметов
      final sbjRes = await supabase.from('subjects').select().order('created_at');
      final sbjData = (sbjRes as List)
          .cast<Map<String, dynamic>>()
          .where((s) => s['user_id'] == user.id)
          .toList();

      if (sbjData.isEmpty) {
        setState(() {
          subjects = [];
          avgBySubject = {};
        });
        return;
      }

      // Загрузка только "текущих" оценок
      final gradeRes = await supabase
          .from('grades')
          .select('subject_id, score, category')
          .filter('subject_id', 'in', sbjData.map((e) => e['id']).toList())
          .eq('category', 'current');

      // Средние по текущим
      final Map<String, List<double>> temp = {};

      for (final g in gradeRes) {
        final sid = g['subject_id'] as String;
        final score = (g['score'] as num).toDouble();
        temp.putIfAbsent(sid, () => []);
        temp[sid]!.add(score);
      }

      final avgMap = {
        for (var k in temp.keys)
          k: temp[k]!.isNotEmpty
              ? temp[k]!.reduce((a, b) => a + b) / temp[k]!.length
              : 0.0
      };

      setState(() {
        subjects = sbjData;
        avgBySubject = avgMap;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addSubjectDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFFFE),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Добавить предмет',
              style: TextStyle(color: Color(0xFF762640), fontWeight: FontWeight.w500, fontSize: 18)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Название предмета',
            hintStyle: TextStyle(color: Color.fromARGB(255, 122, 105, 105), fontWeight: FontWeight.w400, fontSize: 15)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF762640)),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();
                await _createSubject(name);
              },
              child: const Text('Добавить', style: TextStyle(color: Colors.white),),
            ),
            // Пример кнопки в HomePage, ведущей на страницу аналитики

ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AIAnalyticsPage()),
    );
  },
  child: const Text('Перейти к аналитике'),
)

          ],
        );
      },
    );
  }

  Future<void> _createSubject(String name) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);
    try {
      await supabase.from('subjects').insert({
        'name': name,
        'user_id': user.id,
      }).select();

      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Предмет добавлен')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при добавлении предмета: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteSubject(String id) async {
  try {
    await supabase.from('subjects').delete().eq('id', id);
    setState(() {
      subjects.removeWhere((s) => s['id'] == id);
      avgBySubject.remove(id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Предмет удалён')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ошибка при удалении: $e')),
    );
  }
}


  void _openSubjectDetails(Map<String, dynamic> subject) async {
    final updated = await Navigator.pushNamed(
      context,
      '/subject',
      arguments: subject,
    );

    if (updated == true) {
      // Обновляем среднее для конкретного предмета
      await _loadData();
    }
  }

  Widget _buildSubjectCard(Map<String, dynamic> s) {
    final String id = s['id'] as String;
    final String title = s['name'] ?? 'Без названия';
    final double? avg = avgBySubject[id];

    return GestureDetector(
      onTap: () => _openSubjectDetails(s),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B2A2A)))),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 5),
                  child: Icon(Icons.bar_chart, size: 23, color: Color(0xFF6B1A1A)),
                ),
                const SizedBox(width: 5),
                const Text('Cредний текущий',
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
                const Spacer(),
                if (avg != null)
                  Text(avg.toStringAsFixed(2),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: avg >= 90
                              ? const Color.fromARGB(255, 62, 170, 66)
                              : (avg >= 70 ? const Color.fromARGB(255, 214, 131, 7) : const Color.fromARGB(255, 150, 49, 42))))
                else
                  const Text('--', style: TextStyle(fontSize: 20, color: Colors.black38)),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEFD).withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Icon(Icons.menu_book, size: 72, color: Color(0xFF762640)),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Пока что у тебя нет предметов',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавь первый предмет, чтобы начать отслеживать оценки.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFFFFEFD),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFF762640),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(userName.isNotEmpty ? userName : 'Имя не задано',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 4),
            Text(userEmail, style: const TextStyle(color: Colors.black54, fontSize: 16)),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Выйти', style: TextStyle(fontWeight: FontWeight.w500),),
              onTap: () async {
                await supabase.auth.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/auth');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFD),
      drawer: _buildDrawer(),
      appBar: AppBar(
        leading: IconButton(
  icon: const Icon(Icons.arrow_back),
  onPressed: () {
    Navigator.pop(context, true);
  },
),
        backgroundColor: const Color(0xFF762640),
        leadingWidth: 50,      // уменьшаем ширину под гамбургер
        titleSpacing: 0,
        title: const Text('Мои предметы', style: TextStyle(fontWeight: FontWeight.w500, letterSpacing: -0.5, fontSize: 20)),
        actions: [
          IconButton(
            onPressed: _loadData, // обновление всех предметов
            icon: const Padding(
              padding: EdgeInsets.only(right: 10, top: 2),
              child: Icon(Icons.refresh, size: 27,),
            ),
          )
        ],
      ),
      
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : subjects.isEmpty
                ? _buildEmptyState()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.separated(
                      itemCount: subjects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final subject = subjects[index];

                        return Dismissible(
                          key: Key(subject['id']),
                          direction: DismissDirection.startToEnd,
                          background: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA03D5C).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.delete, color: Colors.white, size: 30),
                          ),
                          confirmDismiss: (_) async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFFFFFEFD),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                title: const Center(
                                  child: Text(
                                    'Подтверждение',
                                    style: TextStyle(
                                      color: Color(0xFF762640),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                content: const Text(
                                  'Удалить этот предмет?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black87, fontSize: 16),
                                ),
                                actionsAlignment: MainAxisAlignment.center,
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Отмена'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF762640),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Удалить', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            return confirmed ?? false;
                          },
                          onDismissed: (_) async {
                            // Вибрация при подтверждённом удалении
                            HapticFeedback.heavyImpact();

                            // Анимация плавного исчезновения карточки
                            setState(() {
                              subjects.removeAt(index);
                            });

                            await _deleteSubject(subject['id']);
                          },
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            opacity: 1,
                            child: _buildSubjectCard(subject),
                          ),
                        );
                      },
                    ),

                  ),
      ),
      
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          onPressed: _addSubjectDialog,
          backgroundColor: const Color(0xFF762640),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)
          ),
          child: const Icon(Icons.add, color: Colors.white,),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      
    );
  }
}