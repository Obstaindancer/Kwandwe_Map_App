import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/map/map_screen.dart';

class KwandweApp extends StatelessWidget {
  const KwandweApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kwandwe Map',
      debugShowCheckedModeBanner: false,
      theme: KwandweTheme.light(),
      home: const MapScreen(),
    );
  }
}
