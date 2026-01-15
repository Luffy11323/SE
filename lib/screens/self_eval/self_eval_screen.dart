import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class ResultsScreen extends StatelessWidget {
  final Map<String, int> currentScores;
  final String userId;

  const ResultsScreen({
    super.key,
    required this.currentScores,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluation Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _exportData(context),
          ),
        ],
      ),
      body: _ResultsBody(
        currentScores: currentScores,
        userId: userId,
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final csvData =
          'category,score,timestamp\nProfessional Skills,38,2024-07-18';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/evaluations.csv');
      await file.writeAsString(csvData);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Here are your evaluation results.',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    }
  }
}

class _ResultsBody extends StatefulWidget {
  final Map<String, int> currentScores;
  final String userId;

  const _ResultsBody({
    required this.currentScores,
    required this.userId,
  });

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> {
  late Future<List<QueryDocumentSnapshot>> _historicalData;

  final List<Color> _scoreColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.lightGreen,
    Colors.green,
  ];

  @override
  void initState() {
    super.initState();
    _historicalData = _loadHistoricalData();
  }

  Future<List<QueryDocumentSnapshot>> _loadHistoricalData() async {
    if (widget.userId.isEmpty) return [];
    final snapshot = await FirebaseFirestore.instance
        .collection('users/${widget.userId}/selfEvaluations')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();
    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _historicalData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final historicalData = snapshot.data ?? [];

        return ListView(
          children: [
            _buildCurrentScoresCard(),
            if (historicalData.isNotEmpty)
              _buildAnalyticsSection(historicalData),
            _buildHistoryList(historicalData),
          ],
        );
      },
    );
  }

  Widget _buildCurrentScoresCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'CURRENT EVALUATION',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...widget.currentScores.entries
                .map((e) => _buildScoreRow(e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String category, int score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(category)),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: score / 50,
              backgroundColor: Colors.grey[200],
              color: _getScoreColor(score),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$score',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getScoreColor(score),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(List<QueryDocumentSnapshot> historicalData) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Text('PERFORMANCE ANALYTICS'),
        const Divider(),
        SizedBox(height: 300, child: _buildLineChart(historicalData)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLineChart(List<QueryDocumentSnapshot> historicalData) {
    final spots = historicalData.reversed.toList().asMap().entries.map((entry) {
      final data = entry.value.data() as Map<String, dynamic>;
      return FlSpot(entry.key.toDouble(), (data['score'] as num).toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(show: true),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<QueryDocumentSnapshot> historicalData) {
    return Column(
      children: historicalData.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ListTile(
          title: Text(data['category']),
          trailing: Text(
            '${data['score']}',
            style: TextStyle(
              color: _getScoreColor(data['score'] as int),
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(DateFormat.yMMMd()
              .format((data['timestamp'] as Timestamp).toDate())),
        );
      }).toList(),
    );
  }

  Color _getScoreColor(int score) {
    final percentage = score / 50;
    return Color.lerp(Colors.red, Colors.green, percentage) ?? Colors.grey;
  }
}
