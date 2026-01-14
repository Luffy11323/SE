// lib/screens/self_eval/module_list_screen.dart (Updated)
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/string_constants.dart';
import 'package:self_evaluator/modules/self_eval/self_eval_screen.dart';

class ModuleListScreen extends StatelessWidget {
  const ModuleListScreen({super.key});

  final List<Map<String, String>> categories = const [
    {
      'name': 'Professional Life',
      'icon': 'business_center',
      'description': 'Evaluate your career skills.',
    },
    {
      'name': 'Intelligence (IQ)',
      'icon': 'lightbulb',
      'description': 'Assess your cognitive abilities.',
    },
    {
      'name': 'Emotional Self',
      'icon': 'sentiment_satisfied',
      'description': 'Understand your emotional responses.',
    },
    {
      'name': 'Social Life',
      'icon': 'people',
      'description': 'Evaluate your social interactions.',
    },
    {
      'name': 'Religious Self',
      'icon': 'mosque',
      'description': 'Reflect on your spiritual practices.',
    },
    {
      'name': 'Identity / Core Values',
      'icon': 'fingerprint',
      'description': 'Explore your core beliefs and values.',
    },
  ];

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'business_center':
        return Icons.business_center;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'sentiment_satisfied':
        return Icons.sentiment_satisfied;
      case 'people':
        return Icons.people;
      case 'mosque':
        return Icons.mosque;
      case 'fingerprint':
        return Icons.fingerprint;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.selfEvalModule)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            childAspectRatio: 1.2,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SelfEvalScreen(category: category['name']!),
                  ),
                );
              },
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIconData(category['icon']!),
                      size: 50,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      category['name']!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category['description']!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
