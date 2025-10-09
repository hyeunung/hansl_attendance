import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// iOS 18 Shader Compilation 문제 해결을 위한 워밍업
class CustomShaderWarmUp extends StatelessWidget {
  const CustomShaderWarmUp({super.key});

  static Future<void> warmUp() async {
    if (!kDebugMode) return;
    
    // Debug code removed
    final stopwatch = Stopwatch()..start();
    
    // 미리 컴파일할 shader 패턴들
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = Paint();
    
    // 1. 기본 도형들
    paint.color = Colors.blue;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), paint);
    canvas.drawCircle(const Offset(50, 50), 25, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 50),
        const Radius.circular(10),
      ),
      paint,
    );
    
    // 2. 그림자 효과
    paint.color = Colors.black.withValues(alpha: 0.2);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(const Rect.fromLTWH(10, 10, 80, 80), paint);
    
    // 3. 그라데이션
    paint.shader = const LinearGradient(
      colors: [Colors.blue, Colors.green],
    ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), paint);
    
    // 4. 텍스트
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Warm Up',
        style: TextStyle(fontSize: 20, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 10));
    
    recorder.endRecording();
    
    stopwatch.stop();
    // Debug code removed
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}