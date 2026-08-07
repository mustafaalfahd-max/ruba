import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// حلقة تقدّم اليوم. تدور عكس عقارب الساعة انطلاقاً من الأعلى، مواءمةً لاتجاه الواجهة العربية.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.kicker,
    required this.big,
    required this.sub,
    this.size = 206,
  });

  final double value; // 0..1
  final Color color;
  final String kicker;
  final String big;
  final String sub;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(v, color),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kicker,
                  style: TextStyle(fontSize: 13, color: RC.ink4, letterSpacing: .6),
                ),
                SizedBox(height: 3),
                Text(
                  big,
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w600, height: 1),
                ),
                SizedBox(height: 3),
                Text(sub, style: TextStyle(fontSize: 16, color: RC.ink3)),
              ],
            ),
          ],
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color);

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 15.0;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = RC.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      -2 * math.pi * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// عمود واحد في رسم الكمية اليومية.
typedef Bar = ({String label, int value});

/// أعمدة الكمية اليومية مع خط الهدف المتقطّع.
class DailyBars extends StatelessWidget {
  const DailyBars({super.key, required this.bars, required this.goal, this.height = 150});

  final List<Bar> bars;
  final int goal;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxVal = math.max(
      goal.toDouble(),
      bars.fold<double>(1, (a, b) => math.max(a, b.value.toDouble())),
    );
    final top = maxVal * 1.1;
    const barsArea = 118.0;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 22 + (goal / top) * barsArea,
            child: CustomPaint(
              size: Size(double.infinity, 1.5),
              painter: _DashedLinePainter(RC.magenta.withValues(alpha: .65)),
            ),
          ),
          LayoutBuilder(builder: (context, box) {
            // الأعمدة تضيق تلقائياً كلما زاد عددها، فعرض الشهر لا يتداخل.
            final width =
                bars.isEmpty ? 26.0 : (box.maxWidth / bars.length - 4).clamp(3.0, 26.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in bars)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: (b.value / top) * barsArea),
                          duration: Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          builder: (_, h, __) => Container(
                            width: width,
                            height: h,
                            decoration: BoxDecoration(
                              color: b.value >= goal ? RC.cyan : RC.cyanPale,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(6),
                                bottom: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 6),
                        SizedBox(
                          height: 16,
                          child: Text(
                            b.label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(fontSize: 11, color: RC.ink4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 6.0, gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dash, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

/// منحنى الوزن — خط بنقاط عند كل قياس.
class WeightCurve extends StatelessWidget {
  const WeightCurve({super.key, required this.values, this.height = 110});

  /// من الأقدم إلى الأحدث.
  final List<double> values;

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: values.length < 2
            ? Center(
                child: Text(
                  'أضف قياسين على الأقل ليظهر المنحنى',
                  style: TextStyle(fontSize: 14, color: RC.ink4),
                ),
              )
            : CustomPaint(painter: _CurvePainter(values)),
      );
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final span = (hi - lo).abs() < 0.001 ? 1.0 : hi - lo;
    const padY = 14.0;
    final stepX = values.length == 1 ? 0.0 : (size.width - 20) / (values.length - 1);

    Offset at(int i) => Offset(
          10 + stepX * i,
          size.height - padY - ((values[i] - lo) / span) * (size.height - padY * 2),
        );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = RC.magenta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()..color = RC.magenta;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(at(i), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.values != values;
}

/// شريط تقدّم أفقي رفيع (الالتزام، تقدّم الكورس، تنزيل التحديث).
class ThinBar extends StatelessWidget {
  const ThinBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
    this.track,
  });

  final double value;
  final Color? color;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: track ?? RC.muted,
          valueColor: AlwaysStoppedAnimation(color ?? RC.cyan),
        ),
      );
}
