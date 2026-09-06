import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SmartBuildingBackdrop(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66030D17), Color(0xFF06131D)],
                stops: [0, .75],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 54, 28, 32),
              child: Column(
                children: [
                  const BrandMark(size: 68),
                  const SizedBox(height: 22),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800, color: EdgeColors.text),
                      children: [
                        TextSpan(text: 'EdgeSpace '),
                        TextSpan(text: 'AI', style: TextStyle(color: EdgeColors.cyan)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Smart Spaces\nHealthier People\nSmarter Tomorrow',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: EdgeColors.text, height: 1.7, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  const _IntroPills(),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell())),
                      child: const Text('Get Started'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell())),
                      child: const Text('Sign In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroPills extends StatelessWidget {
  const _IntroPills();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusChip(label: 'IoT', color: EdgeColors.blue, icon: Icons.sensors),
        StatusChip(label: 'AI', color: EdgeColors.green, icon: Icons.auto_awesome),
        StatusChip(label: 'Smart Buildings', color: EdgeColors.cyan, icon: Icons.apartment),
      ],
    );
  }
}

class _SmartBuildingBackdrop extends StatelessWidget {
  const _SmartBuildingBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BuildingPainter());
  }
}

class _BuildingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A2031), Color(0xFF07131D), Color(0xFF0D2633)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final glow = Paint()
      ..shader = RadialGradient(colors: [EdgeColors.blue.withValues(alpha: .32), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(size.width * .7, size.height * .38), radius: size.width * .65));
    canvas.drawRect(Offset.zero & size, glow);

    final ground = Paint()..color = const Color(0xFF071019);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .62, size.width, size.height * .38), ground);

    final building = Paint()..color = const Color(0xFF132A38);
    final building2 = Paint()..color = const Color(0xFF0F2431);
    final glass = Paint()..color = const Color(0xFF6CB4E9).withValues(alpha: .58);
    final warm = Paint()..color = const Color(0xFFFFD58A).withValues(alpha: .75);

    final baseY = size.height * .72;
    final left = size.width * .12;
    final bw = size.width * .76;
    final bh = size.height * .25;
    final main = RRect.fromRectAndRadius(Rect.fromLTWH(left, baseY - bh, bw, bh), const Radius.circular(8));
    canvas.drawRRect(main, building);

    final wing = RRect.fromRectAndRadius(Rect.fromLTWH(left + bw * .52, baseY - bh * 1.28, bw * .36, bh * 1.28), const Radius.circular(8));
    canvas.drawRRect(wing, building2);

    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 6; col++) {
        final x = left + 18 + col * (bw - 40) / 6;
        final y = baseY - bh + 22 + row * 42;
        final r = Rect.fromLTWH(x, y, 27, 20);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), (row + col) % 3 == 0 ? warm : glass);
      }
    }
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 2; col++) {
        final x = left + bw * .58 + col * 54;
        final y = baseY - bh * 1.18 + row * 38;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 36, 20), const Radius.circular(2)), glass);
      }
    }

    final path = Path()
      ..moveTo(0, size.height * .76)
      ..quadraticBezierTo(size.width * .38, size.height * .70, size.width, size.height * .84)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF030A10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
