import 'package:flutter/material.dart';

class GlobalVars extends ChangeNotifier {
  bool _hasResult = false;
  bool get hasResult => _hasResult;

  void setHasResult(bool value) {
    _hasResult = value;
    notifyListeners();
  }
}