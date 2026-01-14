import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:charts_flutter/flutter.dart' as charts;
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

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Here are your evaluation results.',
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
            // Current Evaluation Card
            _buildCurrentScoresCard(),

            // Analytics Section
            if (historicalData.isNotEmpty)
              _buildAnalyticsSection(historicalData),

            // History List
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
            ...widget.currentScores.entries.map(
              (e) => _buildScoreRow(e.key, e.value),
            ),
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
              value: score / 50, // Adjust denominator as needed
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
        SizedBox(
          height: 300,
          child: charts.TimeSeriesChart(
            _buildTrendData(historicalData),
            animate: true,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<charts.Series<TimeSeriesScore, DateTime>> _buildTrendData(
      List<QueryDocumentSnapshot> docs) {
    return [
      charts.Series<TimeSeriesScore, DateTime>(
        id: 'Scores',
        data: docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return TimeSeriesScore(
            (data['timestamp'] as Timestamp).toDate(),
            (data['score'] as num).toDouble(),
          );
        }).toList(),
        domainFn: (ts, _) => ts.time,
        measureFn: (ts, _) => ts.score,
      )
    ];
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
    final percentage = score / 50; // Adjust denominator to match your max score
    return Color.lerp(Colors.red, Colors.green, percentage) ?? Colors.grey;
  }
}

class TimeSeriesScore {
  final DateTime time;
  final double score;

  TimeSeriesScore(this.time, this.score);
}
