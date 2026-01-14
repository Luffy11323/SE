import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class ResultsScreen extends StatefulWidget {
  final Map<String, int> currentScores;
  final String userId;

  const ResultsScreen({
    super.key,
    required this.currentScores,
    required this.userId,
    required Map<String, int> scores,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late List<charts.Series<dynamic, dynamic>> _chartSeries;
  bool _loading = true;
  List<QueryDocumentSnapshot> _historicalEvaluations = [];
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
    _loadHistoricalData();
  }

  Future<void> _loadHistoricalData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users/${widget.userId}/selfEvaluations')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      setState(() {
        _historicalEvaluations = snapshot.docs;
        _prepareChartData();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _prepareChartData() {
    // Current Scores Series
    final currentSeries = charts.Series<CategoryScore, String>(
      id: 'Current',
      domainFn: (cs, _) => cs.category,
      measureFn: (cs, _) => cs.score,
      data: widget.currentScores.entries.map((e) {
        return CategoryScore(e.key, e.value.toDouble());
      }).toList(),
      colorFn: (_, idx) => charts.ColorUtil.fromDartColor(
          _scoreColors[idx! % _scoreColors.length]),
    );

    // Historical Trend Series
    final trendSeries = charts.Series<TimeSeriesScore, DateTime>(
      id: 'Trend',
      domainFn: (ts, _) => ts.time,
      measureFn: (ts, _) => ts.score,
      data: _historicalEvaluations.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return TimeSeriesScore(
          (data['timestamp'] as Timestamp).toDate(),
          (data['score'] as num).toDouble(),
        );
      }).toList(),
      colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
    );

    _chartSeries = [currentSeries, trendSeries];
  }

  Future<void> _exportData() async {
    final csvHeader = 'Category,Score,Date\n';
    final csvRows = _historicalEvaluations.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return '"${data['category']}",${data['score']},'
          '${DateFormat('yyyy-MM-dd').format((data['timestamp'] as Timestamp).toDate())}';
    }).join('\n');

    await SharePlus.instance.share(
      ShareParams(
        text: '$csvHeader$csvRows',
        subject: 'Evaluation Results Export',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
            tooltip: 'Export Data',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoricalData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Current Results Card
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT EVALUATION',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...widget.currentScores.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key)),
                            SizedBox(
                              width: 200,
                              child: LinearProgressIndicator(
                                value: e.value / 50,
                                backgroundColor: Colors.grey[200],
                                color: _scoreColors[e.value ~/ 10],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${e.value}'),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Analytics Section Header
            const Text(
              'PERFORMANCE ANALYTICS',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Divider(),

            // Charts
            Expanded(
              child: ListView(
                children: [
                  SizedBox(
                    height: 300,
                    child: charts.TimeSeriesChart(
                      _chartSeries
                          .whereType<charts.Series<TimeSeriesScore, DateTime>>()
                          .toList(),
                      animate: true,
                      behaviors: [
                        charts.SeriesLegend(
                          position: charts.BehaviorPosition.bottom,
                        ),
                        charts.ChartTitle(
                          'Evaluation Trend',
                          behaviorPosition: charts.BehaviorPosition.bottom,
                          titleStyleSpec:
                              const charts.TextStyleSpec(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    child: charts.BarChart(
                      _chartSeries
                          .whereType<charts.Series<CategoryScore, String>>()
                          .toList(),
                      animate: true,
                      barGroupingType: charts.BarGroupingType.grouped,
                      behaviors: [
                        charts.SeriesLegend(
                          position: charts.BehaviorPosition.bottom,
                        ),
                        charts.ChartTitle(
                          'Category Scores',
                          behaviorPosition: charts.BehaviorPosition.bottom,
                          titleStyleSpec:
                              const charts.TextStyleSpec(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryScore {
  final String category;
  final double score;

  CategoryScore(this.category, this.score);
}

class TimeSeriesScore {
  final DateTime time;
  final double score;

  TimeSeriesScore(this.time, this.score);
}
