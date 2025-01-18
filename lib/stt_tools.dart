import 'dart:async';
import 'package:flutter/material.dart';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SttValues {
  String lastWords = "";
  bool onListen = false;
}

class SttTools extends ChangeNotifier {
  void start() {
    _startListening();
  }
  SpeechToText _speechToText = SpeechToText();
  bool onListen = false;
  final SttValues sttValues = SttValues();

  String lastWords = "";

  void initSpeech() async {
    await _speechToText.initialize();
  }

  void _startListening() async {
    await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 60),
        cancelOnError: false,
        partialResults: false,
        listenMode: ListenMode.confirmation,
    );
  }

  void restart() async {
    lastWords = "";
    sttValues.lastWords = lastWords;
    onListen = true;
    sttValues.onListen = onListen;
    start();
    notifyListeners();
  }

  Future<void> pause() async {
    await stop();
    onListen = false;
    sttValues.onListen = onListen;
    notifyListeners();
  }

  Future<void> stop() async {
    await _speechToText.stop();
  }

  String longestCommonPostfix(String text1, String text2) {
    int minLength = text1.length < text2.length ? text1.length : text2.length;
    int end1 = text1.length;
    int end2 = text2.length;
    if (end1 <= 0 || end2 <= 0) {
      return '';
    }
    String postfix = '';

    for (int i = 0; i < minLength; i++) {
      if (text1[end1 - minLength + i] == text2[end2 - minLength + i]) {
        postfix += text1[end1 - minLength + i];
      } else {
        return '';
      }
    }

    return postfix;
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    String text = result.recognizedWords.toString().toLowerCase();
    if (text.isNotEmpty) {
      lastWords = text;
      sttValues.lastWords = lastWords;
      notifyListeners();
    }
    debugPrint(lastWords);
  }
}