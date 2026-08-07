import 'package:flutter/material.dart';

import '../../theme.dart';

/// البطاقة البيضاء المستعملة في كل الشاشات.
class RubaCard extends StatelessWidget {
  const RubaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color,
    this.shadowOpacity = .10,
    this.onTap,
    this.outline,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// فارغ يعني لون البطاقة الافتراضي — لا يمكن أن يكون قيمة افتراضية
  /// في بانٍ const لأنه يتغيّر مع الوضع الداكن.
  final Color? color;
  final double shadowOpacity;
  final VoidCallback? onTap;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? RC.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: RC.shadow(shadowOpacity),
        border: outline == null ? null : Border.all(color: outline!, width: 1.5),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: box,
      ),
    );
  }
}

/// عنوان قسم صغير متباعد الحروف — يفصل مجموعات البطاقات.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = EdgeInsets.zero});

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(
          text,
          style: TextStyle(fontSize: 13, letterSpacing: 1.8, color: RC.ink4),
        ),
      );
}

/// زر اختيار على شكل حبّة — الحالة المحددة بإطار وخلفية تركوازيين.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
    this.height = 46,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: selected ? RC.cyanWash : RC.card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: height,
          // مع alignment غير فارغ يتمدّد Container ليملأ المتاح، وهو مطلوب
          // داخل Expanded فقط. في Wrap نتركه فارغاً ليأخذ الزر عرض نصّه.
          alignment: expand ? Alignment.center : null,
          padding: EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? RC.cyan : RC.hair(.12),
              width: 1.5,
            ),
          ),
          // FittedBox يصغّر النص بدل أن يلفّه إلى سطرين عند ضيق الزر —
          // كان «ملغم» يظهر «ملغ / م» و«عند اللزوم» مقطوعاً.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 15.5,
                color: selected ? RC.cyanDark : RC.ink3,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: btn) : btn;
  }
}

/// مفتاح تشغيل/إيقاف بمقاسات التصميم (50×30).
class RubaSwitch extends StatelessWidget {
  const RubaSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          width: 50,
          height: 30,
          padding: EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? RC.cyan : RC.line,
            borderRadius: BorderRadius.circular(15),
          ),
          child: AnimatedAlign(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            // الاتجاه من اليمين لليسار: المقبض يتحرك يساراً عند التفعيل.
            alignment: value ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// الزر الأساسي الممتلئ.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 56,
    this.fontSize = 19,
    this.color,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: onTap == null ? null : RC.lift(10, .30),
          ),
          child: Material(
            color: onTap == null ? RC.line : (color ?? RC.cyan),
            borderRadius: BorderRadius.circular(height / 2),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(height / 2),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 21, color: Colors.white),
                      SizedBox(width: 8),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// زر بإطار — متصل أو متقطّع كما في التصميم.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.dashed = false,
    this.color,
    this.textColor,
    this.height = 52,
    this.fontSize = 16,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool dashed;
  final Color? color;
  final Color? textColor;
  final double height;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final edge = color ?? RC.cyan;
    final ink = textColor ?? RC.cyanDark;
    final content = Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 21, color: ink),
            SizedBox(width: 8),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: fontSize, color: ink),
              ),
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(height / 2),
          child: dashed
              ? CustomPaint(
                  painter: _DashedBorderPainter(
                    color: edge.withValues(alpha: .45),
                    radius: height / 2,
                  ),
                  child: content,
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height / 2),
                    border: Border.all(color: edge, width: 1.5),
                  ),
                  child: content,
                ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 7.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

/// صف «مفتاح ← قيمة» داخل البطاقات.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: RC.ink4)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: valueStyle ?? TextStyle(fontSize: 16, color: RC.ink),
            ),
          ),
        ],
      );
}

/// حقل إدخال بخلفية بيضاء — الشكل المستعمل في نماذج العلاج والنسخ الاحتياطي.
class FilledField extends StatelessWidget {
  const FilledField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.fontSize = 18,
    this.textDirection,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final double fontSize;
  final TextDirection? textDirection;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: RC.card,
          borderRadius: BorderRadius.circular(15),
          boxShadow: RC.shadow(.07),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          textDirection: textDirection,
          onChanged: onChanged,
          style: TextStyle(fontSize: fontSize, color: RC.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: RC.ghost),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: InputBorder.none,
          ),
        ),
      );
}

/// حقل بخط سفلي — يُستعمل في شاشة الترحيب.
class UnderlineField extends StatelessWidget {
  const UnderlineField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.fontSize = 21,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: RC.ink4)),
          const SizedBox(height: 2),
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x2E201E1D), width: 1.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    readOnly: readOnly,
                    onTap: onTap,
                    style: TextStyle(fontSize: fontSize, color: RC.ink),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: RC.ghost),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (suffix != null)
                  Text(suffix!, style: TextStyle(fontSize: 15, color: RC.ink4)),
              ],
            ),
          ),
        ],
      );
}

/// عدّاد + / − بمقاسات التصميم.
class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onDec,
    required this.onInc,
  });

  final String label;
  final String value;
  final VoidCallback onDec;
  final VoidCallback onInc;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          _round('−', onDec, 20),
          SizedBox(
            width: 44,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ),
          _round('+', onInc, 18),
        ],
      );

  Widget _round(String glyph, VoidCallback onTap, double size) => Material(
        color: RC.surface,
        shape: CircleBorder(side: BorderSide(color: RC.hair(.13))),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(child: Text(glyph, style: TextStyle(fontSize: size))),
          ),
        ),
      );
}

/// رسالة سريعة أسفل الشاشة — مكافئ toast في التصميم.
void flash(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RC.toastBg,
        elevation: 8,
        duration: const Duration(milliseconds: 2600),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 20, color: RC.toastIcon),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 15.5, color: RC.toastInk),
              ),
            ),
          ],
        ),
      ),
    );
}

/// نافذة تأكيد موحّدة للعمليات التي لا تراجع فيها.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'متابعة',
  Color? confirmColor,
}) async {
  final accent = confirmColor ?? RC.cyan;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: RC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
      content: Text(message, style: TextStyle(fontSize: 16, height: 1.7, color: RC.ink3)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('إلغاء', style: TextStyle(color: RC.ink3, fontSize: 16)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: TextStyle(color: accent, fontSize: 16)),
        ),
      ],
    ),
  );
  return r ?? false;
}
