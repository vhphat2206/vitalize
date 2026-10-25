import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../app/toast.dart';
import '../logic/format.dart';
import '../logic/reminders.dart';
import '../state/log_store.dart';
import '../state/prefs_store.dart';
import '../widgets/back_bar.dart';
import '../widgets/controls.dart';
import '../widgets/icons.dart';
import '../widgets/modal_sheet.dart';
import '../widgets/stepper.dart';
import 'profile/entrance.dart';
import 'profile/wrap_text.dart';

/// Settings, pushed from the profile tab: haptics, keeping the screen awake, training
/// reminders, clearing the logs kept on this phone, and app information.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// 7 → "07"
String _two(int n) => n.toString().padLeft(2, '0');

enum _Info { health, licences }

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _entrance = EntranceClock(this, lastDelay: 0);
  bool _played = false;
  late final PrefsStore _prefs;

  /// The reminder setting last handed to [Reminders.sync], and a count to drop stale answers.
  Reminder? _synced;
  int _syncs = 0;
  ReminderStatus? _status;

  /// Set when reminders were switched back off because notifications are not allowed;
  /// shows how to allow them until reminders are turned on again.
  ReminderStatus? _refused;

  _Info? _open;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefs = context.read<PrefsStore>()..addListener(_onPrefs);
    _sync(_prefs.settings.reminder);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_played) {
      _played = true;
      _entrance.play(context);
    }
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefs);
    WidgetsBinding.instance.removeObserver(this);
    _entrance.dispose();
    super.dispose();
  }

  /// Re-schedule whenever the reminder setting changes; the phone keeps them across launches.
  void _onPrefs() {
    final r = _prefs.settings.reminder;
    if (!identical(r, _synced)) _sync(r);
  }

  Future<void> _sync(Reminder r, {bool ask = true}) async {
    _synced = r;
    final run = ++_syncs;
    ReminderStatus status;
    try {
      status = await Reminders.instance.sync(r, ask: ask);
    } catch (e) {
      debugPrint('Training reminders: $e');
      status = ReminderStatus.denied; // as on the web: a failure reads as "not allowed"
    }
    if (run != _syncs) return; // a newer change has taken over
    if (r.enabled &&
        (status == ReminderStatus.denied || status == ReminderStatus.permanentlyDenied)) {
      // No permission to notify: switch the reminder back off and say how to allow it.
      if (mounted) setState(() => _refused = status);
      _setReminder(enabled: false);
      return;
    }
    if (mounted) setState(() => _status = status);
  }

  /// Back in the app, notifications may have been allowed or turned off in the phone's
  /// Settings meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_refused != null) {
      _recheck();
    } else if (_prefs.settings.reminder.enabled) {
      // Turned off in Settings: the sync finds out and switches the reminder off (no dialog).
      _sync(_prefs.settings.reminder, ask: false);
    }
  }

  /// Back from the phone's Settings: if notifications are allowed now, turn the reminder on.
  Future<void> _recheck() async {
    final allowed = await Reminders.instance.notificationsAllowed();
    if (!mounted || _refused == null || !allowed) return;
    setState(() => _refused = null);
    _setReminder(enabled: true);
  }

  void _setReminder({bool? enabled, List<int>? days, int? hour, int? minute}) {
    final s = _prefs.settings;
    _prefs.updateSettings(
      s.copyWith(
        reminder: s.reminder.copyWith(enabled: enabled, days: days, hour: hour, minute: minute),
      ),
    );
  }

  void _toggleDay(int day) {
    final days = _prefs.settings.reminder.days;
    _setReminder(
      days: days.contains(day) ? days.where((d) => d != day).toList() : ([...days, day]..sort()),
    );
  }

  void _editTime(Reminder r) => showModalSheet<void>(
    context,
    title: 'Giờ nhắc',
    builder: (sheet) => _TimeEditor(
      hour: r.hour,
      minute: r.minute,
      onSave: (hour, minute) {
        _setReminder(hour: hour, minute: minute);
        Navigator.of(sheet).pop();
      },
    ),
  );

  void _confirmClear({required bool meals}) {
    final log = context.read<LogStore>();
    final what = meals
        ? 'Xoá hết ${log.meals.length} bữa ăn đã lưu.'
        : 'Xoá hết ${log.sets.length + log.sessions.length} mục đã ghi (hiệp tập và buổi tập '
              'ngắn).';
    showModalSheet<void>(
      context,
      title: meals ? 'Xoá nhật ký ăn uống?' : 'Xoá nhật ký tập?',
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$what Không khôi phục lại được.', style: VT.ui(15.5)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: GhostButton(
                    label: 'Thôi, giữ lại',
                    onPressed: () => Navigator.of(sheet).pop(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: GhostButton(
                    label: 'Xoá hết',
                    danger: true,
                    onPressed: () {
                      log.clear(training: !meals, meals: meals);
                      Toast.show(context, meals ? 'Đã xoá nhật ký ăn uống' : 'Đã xoá nhật ký tập');
                      Navigator.of(sheet).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The quiet line under the reminder group, as on the web.
  String? _reminderNote(Reminder r) => switch (_status) {
    ReminderStatus.unsupported => 'Nhắc lịch chỉ chạy trong app trên điện thoại.',
    ReminderStatus.scheduled when r.enabled =>
      'Sẽ nhắc lúc ${_two(r.hour)}:${_two(r.minute)} vào '
          '${r.days.map((d) => weekdayShort[d]).join(', ')}.',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<PrefsStore>().settings;
    final log = context.watch<LogStore>();
    final r = settings.reminder;
    final insets = MediaQuery.paddingOf(context);
    final training = log.sets.length + log.sessions.length;
    final meals = log.meals.length;
    final refused = _refused;

    return Entrance(
      clock: _entrance,
      child: ScrolledPast(
        threshold: 40,
        builder: (context, scrolled, controller) => Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                controller: controller,
                padding: EdgeInsets.only(top: insets.top + 58, bottom: insets.bottom + 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The heading keeps the mask line's room for stacked marks (0.08 em above,
                    // 0.06 em below, 0.04 em at the sides) inside its margins.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        V.pad + 0.04 * 34,
                        0.08 * 34,
                        V.pad + 0.04 * 34,
                        0.06 * 34 + 26,
                      ),
                      child: MaskLine(
                        fontSize: 34,
                        child: Text(
                          'Cài đặt',
                          // Leading split evenly above and below, as CSS does (see profile).
                          style: VT
                              .display(34, height: 1.15, em: -0.025)
                              .copyWith(leadingDistribution: TextLeadingDistribution.even),
                        ),
                      ),
                    ),
                    Group(
                      title: 'Khi tập',
                      children: [
                        ToggleRow(
                          label: 'Rung khi đếm giờ',
                          hint: 'Rung nhẹ ở 3 giây cuối mỗi động tác và khi lưu.',
                          value: settings.haptics,
                          onChanged: (on) =>
                              _prefs.updateSettings(_prefs.settings.copyWith(haptics: on)),
                        ),
                        ToggleRow(
                          label: 'Giữ màn hình sáng',
                          hint: 'Trong lúc chạy đồng hồ buổi tập.',
                          value: settings.keepAwake,
                          onChanged: (on) =>
                              _prefs.updateSettings(_prefs.settings.copyWith(keepAwake: on)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Group(
                      title: 'Nhắc lịch tập',
                      children: [
                        ToggleRow(
                          label: 'Nhắc tôi đi tập',
                          value: r.enabled,
                          onChanged: (on) {
                            // Turning it on asks for permission to notify (see _sync).
                            if (on) setState(() => _refused = null);
                            _setReminder(enabled: on);
                          },
                        ),
                        if (r.enabled) ...[
                          _DayPicker(days: r.days, onToggle: _toggleDay),
                          ValueRow(
                            label: 'Giờ nhắc',
                            value: Text(
                              '${_two(r.hour)}:${_two(r.minute)}',
                              style: VT.mono(13.5, color: V.muted),
                            ),
                            onTap: () => _editTime(r),
                          ),
                        ],
                        if (refused != null)
                          _PermissionNotice(
                            blocked: refused == ReminderStatus.permanentlyDenied,
                            onOpenSettings: Reminders.instance.openSettings,
                          )
                        else if (_reminderNote(r) case final note?)
                          _Note(note),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Group(
                      title: 'Dữ liệu của bạn',
                      children: [
                        ValueRow(
                          label: 'Xoá nhật ký tập',
                          hint: training > 0
                              ? '${log.sets.length} hiệp và ${log.sessions.length} buổi tập ngắn'
                              : 'Chưa có gì để xoá',
                          danger: training > 0,
                          onTap: () {
                            if (training > 0) _confirmClear(meals: false);
                          },
                        ),
                        ValueRow(
                          label: 'Xoá nhật ký ăn uống',
                          hint: meals > 0 ? '$meals bữa ăn' : 'Chưa có gì để xoá',
                          danger: meals > 0,
                          onTap: () {
                            if (meals > 0) _confirmClear(meals: true);
                          },
                        ),
                        const _Note(
                          'Nhật ký chỉ lưu trên điện thoại này, chưa đồng bộ lên tài khoản.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Group(
                      title: 'Thông tin',
                      children: [
                        ValueRow(
                          label: 'Lưu ý sức khỏe',
                          onTap: () =>
                              setState(() => _open = _open == _Info.health ? null : _Info.health),
                        ),
                        if (_open == _Info.health)
                          const _InfoText(
                            'Bài tập, số hiệp và lượng ăn trong Vitalize là gợi ý chung cho người '
                            'trưởng thành khỏe mạnh, không thay cho lời khuyên của bác sĩ. Nếu bạn '
                            'có bệnh nền, đang mang thai hoặc từng chấn thương, hỏi bác sĩ hoặc huấn '
                            'luyện viên trước khi tập. Calo từ ảnh là ước tính.',
                          ),
                        ValueRow(
                          label: 'Nguồn và giấy phép',
                          onTap: () => setState(
                            () => _open = _open == _Info.licences ? null : _Info.licences,
                          ),
                        ),
                        if (_open == _Info.licences)
                          const _InfoText(
                            'Hình cơ thể dựa trên react-native-body-highlighter của ELABBASSI '
                            'Hicham, giấy phép MIT. Font Prompt, Be Vietnam Pro và JetBrains Mono '
                            'theo giấy phép SIL Open Font License 1.1.',
                          ),
                        const _VersionRow(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: BackBar(title: 'Cài đặt', solid: scrolled),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seven day buttons, Monday first; the chosen days are filled green.
class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.days, required this.onToggle});

  final List<int> days;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Ngày nhắc',
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V.pad, vertical: 14),
          child: Row(
            children: [
              for (var day = 0; day < 7; day++) ...[
                if (day > 0) const SizedBox(width: 6),
                Expanded(
                  child: _DayButton(
                    label: weekdayShort[day],
                    on: days.contains(day),
                    onTap: () => onToggle(day),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Positioned(
          left: V.pad,
          right: V.pad,
          bottom: 0,
          child: SizedBox(height: 1, child: ColoredBox(color: V.line)),
        ),
      ],
    ),
  );
}

class _DayButton extends StatelessWidget {
  const _DayButton({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: V.easeSwift,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? V.accent : const Color(0x00000000),
          borderRadius: BorderRadius.circular(V.rControl),
          border: Border.all(color: on ? const Color(0x00000000) : V.lineStrong),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          curve: V.easeSwift,
          style: VT.ui(13, weight: FontWeight.w500, height: 1, color: on ? V.accentInk : V.muted),
          child: Text(label),
        ),
      ),
    ),
  );
}

/// Why reminders went back off, and the way to the phone's Settings to allow notifications.
class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({required this.blocked, required this.onOpenSettings});

  /// True when the system will not ask again (permanently denied), false when it still may.
  final bool blocked;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(V.pad, 12, V.pad, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrettyText(
          blocked
              ? 'Thông báo của Vitalize đang tắt nên chưa nhắc được. Mở Cài đặt, vào mục Thông '
                    'báo và cho phép, rồi quay lại đây.'
              : 'Bạn chưa cho phép Vitalize gửi thông báo nên chưa nhắc được. Bật lại để được '
                    'hỏi lần nữa, hoặc cho phép trong Cài đặt.',
          style: VT.ui(14, height: 1.5),
        ),
        const SizedBox(height: 12),
        GhostButton(label: 'Mở Cài đặt', icon: VIcons.external, onPressed: onOpenSettings),
      ],
    ),
  );
}

/// The quiet line under a group (the web's `.group-note`), wrapped without a lone last word.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(V.pad, 10, V.pad, 0),
    child: PrettyText(text, style: VT.ui(13, color: V.muted)),
  );
}

/// An expanded info row: a paragraph ruled underneath like the rows around it.
class _InfoText extends StatelessWidget {
  const _InfoText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(V.pad, 12, V.pad, 16),
        child: PrettyText(text, style: VT.ui(14, height: 1.55, color: V.muted)),
      ),
      const Positioned(
        left: V.pad,
        right: V.pad,
        bottom: 0,
        child: SizedBox(height: 1, child: ColoredBox(color: V.line)),
      ),
    ],
  );
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: V.pad),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Phiên bản', style: VT.ui(15)),
        // The pubspec version, which the Flutter tool builds into the app.
        Text(appBuildName ?? '', style: VT.mono(13.5, color: V.muted)),
      ],
    ),
  );
}

/// Hour and minute steppers side by side, and "Lưu giờ nhắc".
class _TimeEditor extends StatefulWidget {
  const _TimeEditor({required this.hour, required this.minute, required this.onSave});

  final int hour;
  final int minute;
  final void Function(int hour, int minute) onSave;

  @override
  State<_TimeEditor> createState() => _TimeEditorState();
}

class _TimeEditorState extends State<_TimeEditor> {
  late double _h = widget.hour.toDouble();
  late double _m = widget.minute.toDouble();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: VStepper(
              label: 'Giờ',
              unit: '',
              value: _h,
              step: 1,
              min: 0,
              max: 23,
              format: (v) => _two(v.round()),
              onChanged: (v) => setState(() => _h = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: VStepper(
              label: 'Phút',
              unit: '',
              value: _m,
              step: 5,
              min: 0,
              max: 55,
              format: (v) => _two(v.round()),
              onChanged: (v) => setState(() => _m = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      PrimaryButton(label: 'Lưu giờ nhắc', onPressed: () => widget.onSave(_h.round(), _m.round())),
    ],
  );
}
