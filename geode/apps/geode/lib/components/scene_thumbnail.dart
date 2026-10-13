import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'material_orb.dart';
import '../three_d/asset_3d.dart';

class SceneThumbnail extends StatelessWidget {
  const SceneThumbnail({super.key, required this.materialIndex, this.height = 140, this.child});
  final int materialIndex;
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final index = materialIndex.clamp(0, 2).toInt();
    final tint = [const Color(0x1E549DB5), const Color(0x38AD81B8), const Color(0x5534384A)][index];
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Asset3D(asset: Geode3DAsset.forestSanctuary, fallback: Image.asset(
              'assets/images/forest-sanctuary.png',
              fit: BoxFit.cover,
              alignment: Alignment(index * .55 - .55, .15),
              excludeFromSemantics: true,
              errorBuilder: (_, error, trace) => const ColoredBox(color: Color(0xFF173C45)),
            )),
            ColoredBox(color: tint),
            Align(
              alignment: Alignment(.1 + index * .2, -.24),
              child: Asset3D.boxed(asset: Geode3DAsset.fernDew, width: height * .94, height: height * .94, fallback: Image.asset(
                'assets/images/fern-dew.png',
                width: height * .94,
                height: height * .94,
                fit: BoxFit.contain,
                color: index == 1 ? const Color(0x22D7C1EB) : index == 2 ? const Color(0x447A8996) : null,
                colorBlendMode: BlendMode.srcATop,
                excludeFromSemantics: true,
                errorBuilder: (_, error, trace) => MaterialOrb(materialIndex: index, size: height * .63),
              )),
            ),
            IgnorePointer(child: CustomPaint(painter: _DewPainter(index))),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x0006151D), Color(0x2206151D), Color(0xE506151D)],
                stops: [0, .48, 1],
              )),
            ),
            if (child != null) Align(alignment: Alignment.bottomLeft, child: Padding(padding: const EdgeInsets.all(16), child: child)),
          ],
        ),
      ),
    );
  }
}

class _DewPainter extends CustomPainter {
  const _DewPainter(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(37 + seed);
    for (var index = 0; index < 9; index++) {
      final p = Offset(size.width * (.08 + random.nextDouble() * .84), size.height * (.1 + random.nextDouble() * .58));
      final radius = 1.5 + random.nextDouble() * 2.8;
      canvas.drawCircle(p, radius, Paint()..shader = const RadialGradient(
        center: Alignment(-.45, -.5),
        colors: [Color(0xDDFFFFFF), Color(0x33549CB6), Color(0x55376071)],
      ).createShader(Rect.fromCircle(center: p, radius: radius)));
    }
    final ripple = Rect.fromCenter(center: Offset(size.width * .55, size.height * .71), width: size.width * .68, height: size.height * .14);
    canvas.drawOval(ripple, Paint()..color = const Color(0x407BC7DB)..style = PaintingStyle.stroke..strokeWidth = .8);
    canvas.drawOval(ripple.inflate(6), Paint()..color = const Color(0x196BAFBE)..style = PaintingStyle.stroke..strokeWidth = .65);
  }

  @override
  bool shouldRepaint(_DewPainter oldDelegate) => oldDelegate.seed != seed;
}
