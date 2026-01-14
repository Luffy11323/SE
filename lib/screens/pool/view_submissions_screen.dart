import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class ViewSubmissionsScreen extends StatelessWidget {
  final String poolId;
  const ViewSubmissionsScreen({super.key, required this.poolId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Feedback Results")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedbackPools/$poolId/submissions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final submissions = snapshot.data!.docs;
          if (submissions.isEmpty) {
            return const Center(child: Text("No submissions yet"));
          }

          // Calculate average scores per question
          final scoreData = _calculateAverages(submissions);

          return Column(
            children: [
              SizedBox(
                height: 200,
                child: charts.BarChart(
                  _buildChartSeries(scoreData),
                  animate: true,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: submissions.length,
                  itemBuilder: (context, index) {
                    final submission = submissions[index];
                    return ExpansionTile(
                      title: Text("Feedback ${index + 1}"),
                      children: [
                        ...submission['answers'].entries.map((e) {
                          return ListTile(
                            title: Text(e.key),
                            trailing: Text("Score: ${e.value}"),
                          );
                        }),
                        if (submission['textFeedback'] != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child:
                                Text("Comments: ${submission['textFeedback']}"),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, double> _calculateAverages(
      List<QueryDocumentSnapshot> submissions) {
    final Map<String, List<int>> questionScores = {};

    for (final submission in submissions) {
      final answers = submission['answers'] as Map<String, dynamic>;
      answers.forEach((questionId, score) {
        questionScores.putIfAbsent(questionId, () => []).add(score as int);
      });
    }

    return questionScores.map((key, scores) => MapEntry(
          key,
          scores.reduce((a, b) => a + b) / scores.length,
        ));
  }

  List<charts.Series<MapEntry<String, double>, String>> _buildChartSeries(
      Map<String, double> data) {
    return [
      charts.Series<MapEntry<String, double>, String>(
        id: 'Scores',
        domainFn: (entry, _) => entry.key,
        measureFn: (entry, _) => entry.value,
        data: data.entries.toList(),
        labelAccessorFn: (entry, _) => entry.value.toStringAsFixed(1),
      )
    ];
  }
}
