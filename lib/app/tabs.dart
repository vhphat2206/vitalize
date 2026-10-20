import 'package:flutter/foundation.dart';

enum AppTab { body, routines, food, week, profile }

/// The selected tab. Screens can switch tabs with `context.read<TabNav>().go(AppTab.week)`.
class TabNav extends ChangeNotifier {
  AppTab _tab = AppTab.body;

  AppTab get tab => _tab;

  void go(AppTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }
}
