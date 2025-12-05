import 'package:flutter/material.dart';
import 'screens/camera_screen_complete.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SimpleCameraApp());
}

class SimpleCameraApp extends StatelessWidget {
  const SimpleCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Camera',
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const CameraScreen(),
    );
  }
}
