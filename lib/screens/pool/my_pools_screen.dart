import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:self_evaluator/screens/pool/create_pool_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';

class MyPoolsScreen extends StatefulWidget {
  const MyPoolsScreen({super.key});

  @override
  State<MyPoolsScreen> createState() => _MyPoolsScreenState();
}

class _MyPoolsScreenState extends State<MyPoolsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _refreshPools() async {
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(child: Text("Please log in to view your pools."));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Feedback Pools"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.iconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CreatePoolScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedbackPools')
            .where('ownerUserId', isEqualTo: currentUser!.uid)
            .orderBy('creationTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("You haven't created any feedback pools yet."));
          }

          return RefreshIndicator(
            onRefresh: _refreshPools,
            child: ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final poolDoc = snapshot.data!.docs[index];
                final poolData = poolDoc.data() as Map<String, dynamic>;
                final category = poolData['category'] ?? 'N/A';
                final creationDate =
                    (poolData['creationTimestamp'] as Timestamp?)?.toDate();
                final shareLinkToken = poolData['shareLinkToken'] ?? '';
                final String shareLink =
                    "https://yourapp.com/feedback/$shareLinkToken";

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('feedbackPools/${poolDoc.id}/submissions')
                      .snapshots(),
                  builder: (context, subSnapshot) {
                    if (subSnapshot.hasData &&
                        subSnapshot.data!.docs.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        await Vibration.hasVibrator().then((hasVibrator) {
                          if (hasVibrator) {
                            Vibration.vibrate(pattern: [0, 200, 100, 200]);
                          }
                        });
                      });
                    }

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Category: $category",
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                "Created: ${creationDate?.toLocal().toString().split(' ')[0] ?? 'N/A'}"),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "View submissions (Coming Soon)")),
                                    );
                                  },
                                  icon: const Icon(Icons.visibility),
                                  label: const Text("View Submissions"),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final String message =
                                          "Give me anonymous feedback on my $category skills! Click here: $shareLink";

                                      // Use SharePlus.instance.share() instead of deprecated Share.share()
                                      await SharePlus.instance
                                          .share(message as ShareParams);
                                    } catch (e) {
                                      if (mounted) {
                                        // ignore: use_build_context_synchronously
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Error sharing link: $e")),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text("Share Link"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
