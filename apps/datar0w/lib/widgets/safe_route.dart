import 'package:flutter/material.dart';

/// Si le builder throw, écran jaune visible (plus de snap-back silencieux).
class SafeRoute extends StatelessWidget {
  const SafeRoute({
    super.key,
    required this.name,
    required this.builder,
  });

  final String name;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    try {
      return builder(context);
    } catch (e, st) {
      debugPrint('[route:$name] build failed: $e\n$st');
      return Scaffold(
        backgroundColor: const Color(0xFFFFEB3B),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                'Erreur écran $name\n\n$e',
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}
