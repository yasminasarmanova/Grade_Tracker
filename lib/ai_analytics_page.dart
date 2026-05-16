import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AIAnalyticsPage extends StatefulWidget {
  const AIAnalyticsPage({super.key});

  @override
  State<AIAnalyticsPage> createState() => _AIAnalyticsPageState();
}

class _AIAnalyticsPageState extends State<AIAnalyticsPage> {
  double avgScore = 4.2;
  double weeklyChange = 0.3;
  String bestSubject = "Python";
  String weakSubject = "Java";

  // Пример данных для графика динамики
  final List<FlSpot> weeklyData = [
    FlSpot(0, 3.7),
    FlSpot(1, 3.9),
    FlSpot(2, 4.0),
    FlSpot(3, 4.2),
    FlSpot(4, 4.1),
    FlSpot(5, 4.3),
    FlSpot(6, 4.2),
  ];

  final Map<String, double> subjects = {
    "Python": 4.7,
    "SQL": 4.3,
    "Java": 3.2,
    "Flutter": 2,
  };

  final List<String> aiAdvice = [
    "Ты отлично держишь темп! Продолжай в том же духе 💪",
    "Небольшой спад — не беда. Главное, что ты не останавливаешься!",
    "Средний балл стабилен — это показатель дисциплины 👏",
    "Если продолжишь так, выйдешь на 4.5 уже на следующей неделе 🚀"
  ];

  String getRandomAdvice() {
    final random = Random();
    return aiAdvice[random.nextInt(aiAdvice.length)];
  }

  String currentAdvice = "";

  @override
  void initState() {
    super.initState();
    currentAdvice = getRandomAdvice();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leadingWidth: 50,
        titleSpacing: 0,
        title: const Text("AI Аналитика", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 20)),
        backgroundColor: const Color(0xFF762640),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ---- Карточки статистики ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCard("Средний балл", avgScore.toStringAsFixed(1), Colors.blueAccent),
                _buildCard("Изменение за неделю", "${weeklyChange > 0 ? '+' : ''}${weeklyChange.toStringAsFixed(1)}", weeklyChange > 0 ? Colors.green : Colors.redAccent),
              ],
            ),
            

            const SizedBox(height: 24),

            // ---- График динамики ----
            _buildSectionTitle("Динамика за неделю"),
            SizedBox(
              height: 200,
              child: LineChart(LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: Colors.blueAccent,
                    spots: weeklyData,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  )
                ],
                titlesData: FlTitlesData(show: false),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
              )),
            ),

            const SizedBox(height: 24),

            // ---- Сравнение предметов ----
            _buildSectionTitle("Сравнение предметов"),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: subjects.entries.map((entry) {
                    return BarChartGroupData(
                      x: subjects.keys.toList().indexOf(entry.key),
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          color: entry.value >= 4.5
                              ? Colors.green
                              : entry.value >= 4.0
                                  ? Colors.yellow[700]
                                  : Colors.redAccent,
                          borderRadius: BorderRadius.circular(6),
                        )
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final subject = subjects.keys.elementAt(value.toInt());
                          return Text(subject, style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCard('Лучший предмет', 'Математика', Colors.orange),
                _buildCard('Слабое место', 'История', Colors.red),
              ],
            ),
            const SizedBox(height: 24),
            // ---- Совет от AI ----
            _buildSectionTitle("Совет от AI"),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    currentAdvice,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => currentAdvice = getRandomAdvice());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Обновить анализ"),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String value, Color color) {
    return Container(

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}