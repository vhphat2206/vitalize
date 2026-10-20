import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/tabs.dart';
import '../app/theme.dart';
import '../data/catalog.dart';
import '../logic/format.dart';
import '../logic/nutrition.dart';
import '../state/prefs_store.dart';
import '../widgets/back_bar.dart';
import '../widgets/controls.dart';
import '../widgets/icons.dart';
import '../widgets/modal_sheet.dart';
import '../widgets/stepper.dart';
import 'profile/entrance.dart';
import 'profile/wrap_text.dart';
import 'settings_screen.dart';

/// The "Hồ sơ" tab: who you are, what to eat each day, and the body and goal numbers behind it.
/// Every field opens a short sheet; choices save on tap, numbers on "Lưu".
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

const _goals = [
  (Goal.lose, 'Giảm mỡ', 'Ăn ít hơn mức cơ thể đốt khoảng 400 kcal mỗi ngày.'),
  (Goal.maintain, 'Giữ dáng', 'Ăn vừa bằng mức cơ thể đốt.'),
  (Goal.gain, 'Tăng cơ', 'Ăn dư khoảng 250 kcal mỗi ngày, tập đều để lên cơ.'),
];

const _levelHints = {
  1: 'Mới bắt đầu hoặc nghỉ lâu quay lại.',
  2: 'Tập đều vài tháng, quen các bài cơ bản.',
  3: 'Tập trên một năm, làm chắc kỹ thuật bài nặng.',
};

String _goalPhrase(Goal goal) => switch (goal) {
  Goal.lose => 'Đang giảm mỡ',
  Goal.maintain => 'Đang giữ dáng',
  Goal.gain => 'Đang tăng cơ',
};

/// "Minh Anh" → "MA": the first letters of the last two words.
String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final last = words.length > 2 ? words.sublist(words.length - 2) : words;
  return last.map((w) => w.characters.first.toUpperCase()).join();
}

/// 170.0 → "170", 65.5 → "65.5", as JavaScript prints numbers.
String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Weight with the Vietnamese decimal comma: 65.5 → "65,5".
String _kg(double v) => _plain(v).replaceAll('.', ',');

/// Prompt's tall ascent sits differently in a short line box: CSS splits the leading evenly
/// above and below, Flutter by default in proportion to ascent and descent (2–3 px higher).
TextStyle _even(TextStyle s) => s.copyWith(leadingDistribution: TextLeadingDistribution.even);

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late final _entrance = EntranceClock(this, lastDelay: 0.24);
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab stays mounted while hidden. As on the web (where a hidden tab is display: none),
    // the entrance plays each time the tab comes into view.
    final shown = Provider.of<TabNav>(context).tab == AppTab.profile;
    if (shown && !_shown) _entrance.play(context);
    _shown = shown;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _edit(_Field field) => showModalSheet<void>(
    context,
    title: field.title,
    builder: (_) => _Editor(field: field),
  );

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PrefsStore>().profile;
    final thisYear = DateTime.now().year;
    final birthYear = profile.birthYear;
    final height = profile.heightCm;
    final weight = profile.weightKg;
    const unset = Text('Chưa nhập');
    final number = VT.mono(13.5, color: V.muted);

    return Entrance(
      clock: _entrance,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Head(profile: profile, onEditName: () => _edit(_Field.name)),
            Appear.soft(delay: 0.24, child: _Targets(profile: profile)),
            const SizedBox(height: 30),
            Group(
              title: 'Cơ thể',
              children: [
                ValueRow(
                  label: 'Giới tính',
                  value: Text(switch (profile.sex) {
                    Sex.male => 'Nam',
                    Sex.female => 'Nữ',
                    null => 'Chưa nhập',
                  }),
                  onTap: () => _edit(_Field.sex),
                ),
                ValueRow(
                  label: 'Năm sinh',
                  value: birthYear == null
                      ? unset
                      : Text('$birthYear (${thisYear - birthYear} tuổi)', style: number),
                  onTap: () => _edit(_Field.birthYear),
                ),
                ValueRow(
                  label: 'Chiều cao',
                  value: height == null ? unset : Text('${_plain(height)} cm', style: number),
                  onTap: () => _edit(_Field.height),
                ),
                ValueRow(
                  label: 'Cân nặng',
                  value: weight == null ? unset : Text('${_kg(weight)} kg', style: number),
                  onTap: () => _edit(_Field.weight),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Group(
              title: 'Mục tiêu và tập luyện',
              children: [
                ValueRow(
                  label: 'Mục tiêu',
                  value: Text(_goals.firstWhere((g) => g.$1 == profile.goal).$2),
                  onTap: () => _edit(_Field.goal),
                ),
                ValueRow(
                  label: 'Trình độ',
                  value: Text(catalog.levelLabel[profile.level] ?? ''),
                  onTap: () => _edit(_Field.level),
                ),
                ValueRow(
                  label: 'Số buổi mỗi tuần',
                  value: Text('${profile.daysPerWeek}', style: number),
                  onTap: () => _edit(_Field.days),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar, name and a one-line summary, with the settings button at the top right.
class _Head extends StatelessWidget {
  const _Head({required this.profile, required this.onEditName});

  final Profile profile;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final initials = _initials(profile.name);
    final name = profile.name.trim();
    return Container(
      // The settings button hangs 10 px into the right margin, as on the web.
      padding: EdgeInsets.fromLTRB(V.pad, top + 22, V.pad - 10, 22),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: V.lineStrong)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16 + 44),
            child: Row(
              children: [
                Appear.scale(
                  delay: 0.05,
                  child: Semantics(
                    button: true,
                    label: 'Đổi tên',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onEditName,
                      child: Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: V.bg3,
                          border: Border.all(color: V.accent, width: 1.5),
                        ),
                        child: Text(
                          initials.isEmpty ? '+' : initials,
                          style: _even(VT.display(22, height: 1)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MaskLine(
                        fontSize: 28,
                        delay: 0.1,
                        child: Text(
                          name.isEmpty ? 'Bạn' : name,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: _even(VT.display(28, height: 1.2)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Appear.soft(
                        delay: 0.18,
                        child: BalancedText(
                          '${_goalPhrase(profile.goal)}, tập ${profile.daysPerWeek} buổi mỗi tuần.',
                          style: VT.ui(14, height: 1.4, color: V.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconBtn(
              VIcons.sliders,
              label: 'Cài đặt',
              onPressed: () => Navigator.of(context).push(vRoute(const SettingsScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Mỗi ngày nên ăn": the daily targets, or what is missing to work them out.
class _Targets extends StatelessWidget {
  const _Targets({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final targets = dailyTargets(profile);
    final note = VT.ui(13.5, color: V.muted);
    final missing = [
      if (profile.sex == null) 'giới tính',
      if (profile.birthYear == null) 'năm sinh',
      if ((profile.heightCm ?? 0) == 0) 'chiều cao',
      if ((profile.weightKg ?? 0) == 0) 'cân nặng',
    ];
    return Semantics(
      container: true,
      label: 'Mỗi ngày nên ăn',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(V.pad, 22, V.pad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Mỗi ngày nên ăn'),
            if (targets != null) ...[
              _TargetsTable(targets),
              const SizedBox(height: 12),
              PrettyText(
                'Tính theo công thức Mifflin-St Jeor từ cơ thể, tuổi, số buổi tập và mục tiêu '
                'của bạn. Đây là con số khởi đầu, theo dõi cân nặng vài tuần rồi chỉnh.',
                style: note,
              ),
            ] else ...[
              const SizedBox(height: 12),
              PrettyText(
                'Thêm ${missing.join(', ')} để Vitalize tính lượng ăn mỗi ngày cho bạn.',
                style: note,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Energy and the three macros in a ruled two-by-two table.
class _TargetsTable extends StatelessWidget {
  const _TargetsTable(this.t);

  final Macros t;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: V.line)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            _cell('Năng lượng', '${formatNumber(t.kcal)} kcal', right: false, ruled: true),
            _cell('Đạm', '${t.protein.round()} g', right: true, ruled: true),
          ],
        ),
        Row(
          children: [
            _cell('Tinh bột', '${t.carb.round()} g', right: false, ruled: false),
            _cell('Béo', '${t.fat.round()} g', right: true, ruled: false),
          ],
        ),
      ],
    ),
  );

  Widget _cell(String label, String value, {required bool right, required bool ruled}) => Expanded(
    child: Container(
      padding: EdgeInsets.fromLTRB(right ? 16 : 0, 12, 0, 12),
      decoration: BoxDecoration(
        border: Border(
          left: right ? const BorderSide(color: V.line) : BorderSide.none,
          bottom: ruled ? const BorderSide(color: V.line) : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: VT.ui(13, color: V.muted)),
          const SizedBox(height: 4),
          Text(value, style: VT.mono(20, weight: FontWeight.w500, height: 1.5)),
        ],
      ),
    ),
  );
}

enum _Field {
  name('Tên của bạn'),
  sex('Giới tính'),
  birthYear('Năm sinh'),
  height('Chiều cao'),
  weight('Cân nặng'),
  goal('Mục tiêu'),
  level('Trình độ'),
  days('Số buổi mỗi tuần');

  const _Field(this.title);

  /// The sheet's title.
  final String title;
}

/// A change to the profile, applied when saving.
typedef _Patch = Profile Function(Profile p);

/// The body of a field's sheet. Choices save as soon as you tap; numbers save on "Lưu".
class _Editor extends StatelessWidget {
  const _Editor({required this.field});

  final _Field field;

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PrefsStore>();
    final profile = prefs.profile;
    // Patches apply to the profile as it is when saving, like the web's updateProfile(patch).
    void pick(_Patch patch) {
      prefs.updateProfile(patch(prefs.profile));
      Navigator.of(context).pop();
    }

    return switch (field) {
      _Field.name => _NameEditor(
        initial: profile.name,
        onSave: (n) => pick((p) => p.copyWith(name: n)),
      ),
      _Field.sex => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Giới tính',
            child: Segmented<Sex>(
              options: const [(Sex.male, 'Nam'), (Sex.female, 'Nữ')],
              value: profile.sex,
              onChanged: (sex) => pick((p) => p.copyWith(sex: sex)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dùng để ước tính năng lượng cơ thể đốt mỗi ngày.',
            style: VT.ui(13.5, color: V.muted),
          ),
        ],
      ),
      _Field.goal => ChoiceList<Goal>(
        options: _goals,
        value: profile.goal,
        onChanged: (goal) => pick((p) => p.copyWith(goal: goal)),
      ),
      _Field.level => ChoiceList<int>(
        options: [
          for (final level in [1, 2, 3])
            (level, catalog.levelLabel[level] ?? '', _levelHints[level]!),
        ],
        value: profile.level,
        onChanged: (level) => pick((p) => p.copyWith(level: level)),
      ),
      _Field.birthYear ||
      _Field.height ||
      _Field.weight ||
      _Field.days => _NumberEditor(field: field, profile: profile, onSave: pick),
    };
  }
}

/// Name: a text field and "Lưu"; the keyboard's done key saves too.
class _NameEditor extends StatefulWidget {
  const _NameEditor({required this.initial, required this.onSave});

  final String initial;
  final ValueChanged<String> onSave;

  @override
  State<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends State<_NameEditor> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => widget.onSave(_name.text.trim().characters.take(40).toString());

  @override
  Widget build(BuildContext context) {
    final text = VT.ui(17, weight: FontWeight.w500, height: 1);
    // gapPadding 0: no label gap, so the text sits exactly 14 px in, as on the web.
    OutlineInputBorder ring(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(V.rControl),
      borderSide: BorderSide(color: color, width: width),
      gapPadding: 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          autofillHints: const [AutofillHints.name],
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          inputFormatters: [LengthLimitingTextInputFormatter(40)],
          onSubmitted: (_) => _save(),
          style: text,
          decoration: InputDecoration(
            hintText: 'Ví dụ: Minh Anh',
            hintStyle: text.copyWith(color: V.faint),
            filled: true,
            fillColor: V.bg3,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18.5),
            enabledBorder: ring(V.lineStrong, 1),
            focusedBorder: ring(V.accent, 1.5),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Lưu', onPressed: _save),
      ],
    );
  }
}

/// Birth year, height, weight or sessions a week: a stepper and "Lưu".
class _NumberEditor extends StatefulWidget {
  const _NumberEditor({required this.field, required this.profile, required this.onSave});

  final _Field field;
  final Profile profile;
  final ValueChanged<_Patch> onSave;

  @override
  State<_NumberEditor> createState() => _NumberEditorState();
}

class _NumberEditorState extends State<_NumberEditor> {
  late double _value = switch (widget.field) {
    _Field.birthYear => (widget.profile.birthYear ?? 1998).toDouble(),
    _Field.height => widget.profile.heightCm ?? 165,
    _Field.weight => widget.profile.weightKg ?? 60,
    _ => widget.profile.daysPerWeek.toDouble(),
  };

  @override
  Widget build(BuildContext context) {
    final thisYear = DateTime.now().year;
    final (label, unit, step, min, max) = switch (widget.field) {
      _Field.birthYear => ('Năm sinh', '', 1.0, thisYear - 90.0, thisYear - 12.0),
      _Field.height => ('Chiều cao', 'cm', 1.0, 120.0, 220.0),
      _Field.weight => ('Cân nặng', 'kg', 0.5, 30.0, 200.0),
      _ => ('Số buổi', 'buổi', 1.0, 1.0, 7.0),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VStepper(
          label: label,
          unit: unit,
          value: _value,
          step: step,
          min: min,
          max: max,
          format: widget.field == _Field.weight ? _kg : _plain,
          onChanged: (v) => setState(() => _value = v),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Lưu',
          onPressed: () => widget.onSave(
            (p) => switch (widget.field) {
              _Field.birthYear => p.copyWith(birthYear: _value.round()),
              _Field.height => p.copyWith(heightCm: _value),
              _Field.weight => p.copyWith(weightKg: _value),
              _ => p.copyWith(daysPerWeek: _value.round()),
            },
          ),
        ),
      ],
    );
  }
}
