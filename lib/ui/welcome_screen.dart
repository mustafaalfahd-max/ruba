import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'widgets/common.dart';

/// الترحيب بأربع خطوات: تعريف، بيانات الطفل، الهدف المقترح، التنبيه الطبي.
/// تُستعمل أيضاً لإضافة طفل جديد لاحقاً — عندها تبدأ من الخطوة الثانية.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.startStep = 0, this.asAddChild = false});

  final int startStep;
  final bool asAddChild;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late int _step = widget.startStep;

  final _name = TextEditingController();
  final _dob = TextEditingController();
  final _weight = TextEditingController();
  String _sex = 'f';
  int _goal = 700;

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    _weight.dispose();
    super.dispose();
  }

  double? get _weightValue => double.tryParse(_weight.text.trim());

  Future<void> _next() async {
    if (_step < 3) {
      // عند مغادرة خطوة البيانات نحسب الهدف من الوزن المُدخَل.
      if (_step == 1) {
        final w = _weightValue;
        if (w != null && w > 0) _goal = suggestedGoal(w);
      }
      setState(() => _step++);
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      flash(context, 'اكتب اسم الطفل أولاً');
      setState(() => _step = 1);
      return;
    }
    await AppState.I.addChild(Child(
      id: 0,
      name: name,
      dob: _dob.text.trim().isEmpty ? null : _dob.text.trim(),
      sex: _sex,
      weightKg: _weightValue,
      goalMl: _goal,
      goalAuto: _weightValue != null,
      sortOrder: AppState.I.children.length,
      colorValue:
          AppState.I.children.length.isEven ? 0xFF0088B0 : 0xFFD6006C,
    ));
    await Settings.I.setWelcomeDone(true);
    if (!mounted) return;
    if (widget.asAddChild) {
      Navigator.pop(context);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctas = ['ابدأ', 'التالي', 'التالي', 'فهمت — ادخل التطبيق'];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 3,
                      width: i == _step ? 28 : 14,
                      decoration: BoxDecoration(
                        color: i <= _step ? RC.cyan : RC.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: ctas[_step], onTap: _next),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody() => switch (_step) {
        0 => _intro(),
        1 => _childForm(),
        2 => _goalStep(),
        _ => _medicalNotice(),
      };

  Widget _intro() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'تطبيق رعاية الرضّع',
            style: TextStyle(fontSize: 13, letterSpacing: 2.8, color: RC.ink4),
          ),
          const SizedBox(height: 18),
          Text('ربى', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 18),
          Container(width: 44, height: 3, color: RC.cyan),
          const SizedBox(height: 18),
          SizedBox(
            width: 300,
            child: Text(
              'سجّل رضعات طفلك وجرعات علاجه في مكان واحد. ضغطتان لتسجيل رضعة، '
              'ونظرة واحدة لمعرفة ما تبقّى من هدف اليوم.',
              style: TextStyle(fontSize: 19, height: 1.75, color: RC.ink2),
            ),
          ),
        ],
      );

  Widget _childForm() => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أضف أول طفل', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 18),
            UnderlineField(label: 'الاسم', controller: _name, hint: 'مثلاً: ليان'),
            const SizedBox(height: 18),
            UnderlineField(
              label: 'تاريخ الميلاد',
              controller: _dob,
              hint: 'اختر التاريخ',
              fontSize: 19,
              readOnly: true,
              onTap: _pickDob,
            ),
            const SizedBox(height: 18),
            Text('الجنس', style: TextStyle(fontSize: 14, color: RC.ink4)),
            const SizedBox(height: 9),
            Row(
              children: [
                PillButton(
                  label: 'أنثى',
                  selected: _sex == 'f',
                  expand: true,
                  height: 48,
                  onTap: () => setState(() => _sex = 'f'),
                ),
                const SizedBox(width: 9),
                PillButton(
                  label: 'ذكر',
                  selected: _sex == 'm',
                  expand: true,
                  height: 48,
                  onTap: () => setState(() => _sex = 'm'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 170,
              child: UnderlineField(
                label: 'الوزن الحالي — اختياري',
                controller: _weight,
                hint: '6.8',
                suffix: 'كغ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
      );

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dob.text) ?? now,
      firstDate: DateTime(now.year - 8),
      lastDate: now,
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    setState(() => _dob.text =
        '${picked.year}-${two(picked.month)}-${two(picked.day)}');
  }

  Widget _goalStep() {
    final w = _weightValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الهدف اليومي المقترح', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 20),
        RubaCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$_goal',
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: RC.cyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('مل / يوم', style: TextStyle(fontSize: 18, color: RC.ink4)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                w != null && w > 0
                    ? 'محسوب من الوزن: ${_weight.text.trim()} كغ × 110 مل لكل كيلوغرام.'
                    : 'لا يوجد وزن — هذه قيمة عامة لعمر الرضيع. عدّلها إن أوصى الطبيب بغيرها.',
                style: TextStyle(fontSize: 15, color: RC.ink3, height: 1.7),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _goalBtn('−', () => setState(() => _goal = (_goal - 10).clamp(100, 3000))),
                  const SizedBox(width: 10),
                  _goalBtn('+', () => setState(() => _goal = (_goal + 10).clamp(100, 3000))),
                  const SizedBox(width: 12),
                  Text('بخطوات 10 مل', style: TextStyle(fontSize: 14, color: RC.ink4)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'يمكنك تغييره لاحقاً من ملف الطفل.',
          style: TextStyle(fontSize: 15, color: RC.ink4, height: 1.7),
        ),
      ],
    );
  }

  Widget _goalBtn(String glyph, VoidCallback onTap) => Material(
        color: RC.surface,
        shape: CircleBorder(side: BorderSide(color: RC.hair(.14))),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Center(child: Text(glyph, style: const TextStyle(fontSize: 23))),
          ),
        ),
      );

  Widget _medicalNotice() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services_rounded, size: 44, color: RC.magenta),
          const SizedBox(height: 16),
          Text('تنبيه طبي', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(
            'ربى أداة تسجيل ومتابعة فقط، ولا يقدّم تشخيصاً ولا توصية دوائية. '
            'الجرعات والمواعيد التي تُدخلها هي ما يعرضه التطبيق. '
            'راجع طبيب طفلك قبل أي تغيير في العلاج أو التغذية.',
            style: TextStyle(fontSize: 17, height: 1.85, color: RC.ink2),
          ),
        ],
      );
}
