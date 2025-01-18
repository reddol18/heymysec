import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:mysec/slot_editor.dart';
import 'package:mysec/stt_tools.dart';
import 'package:provider/provider.dart';
import 'calendar_client.dart';
import 'global_vars.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Gemini.init(apiKey: "**your key**");
  runApp(ChangeNotifierProvider(
    create: (context) => SttTools(),
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final SttTools sttTools = Provider.of<SttTools>(context);
    return MaterialApp(
      title: '구글 캘린더 스케쥴 입력기',
      theme: FlexThemeData.light(scheme: FlexScheme.aquaBlue),
      darkTheme: FlexThemeData.dark(scheme: FlexScheme.aquaBlue),
      themeMode: ThemeMode.system,
      home: MyHomePage(
        title: '구글 캘린더 스케쥴 입력기',
        sttValues: sttTools.sttValues,
      ),
    );
  }
}

class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  AuthenticatedClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }
}

class MyHomePage extends StatefulWidget {
  final SttValues sttValues;

  const MyHomePage({super.key, required this.title, required this.sttValues});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late gcal.CalendarList calendarList;
  Map<dynamic, dynamic> resultValue = {};
  // 카테고리 목록
  List<String> categories = [];
  List<String> categorieIds = [];
  late UserCredential firebaseUser;
  // Gemini Result
  String geminiResult = "";

  @override
  void initState() {
    super.initState();
    resultValue = Map<dynamic, dynamic>();
    setState(() {
      Provider.of<SttTools>(context, listen: false).initSpeech();
    });
    /*
    테스트를 위해 수동으로 입력하는 방법
    resultValue["date"] = DateTime(2024, 9, 21);
    resultValue["stime"] = TimeOfDay(hour: 15, minute: 0);
    resultValue["etime"] = TimeOfDay(hour: 17, minute: 30);
    resultValue["category"] = "주간목표";
    resultValue["title"] = "주간 계획 수립";
    */

    signInGoogle();
  }

  void _listenSpeak() {
    setState(() {
      if (widget.sttValues.onListen) {
        Provider.of<SttTools>(context, listen: false).pause();
      } else {
        Provider.of<SttTools>(context, listen: false).restart();
      }
    });
  }
  @override
  void dispose() {
    Provider.of<SttTools>(context, listen: false).stop();
    debugPrint("SignOut");
    googleSignIn.signOut();
    super.dispose();
  }
  GoogleSignInAccount? _currentUser;
  GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
    ],
  );


  Future<void> signInGoogle() async {
    googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      setState(() {
        _currentUser = account;
      });
      if (_currentUser != null) {
        debugPrint("Name of user: ${_currentUser?.displayName}");
          try {
            final googleAuth = await _currentUser!.authentication;
            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            http.Client client = http.Client();
            final authHeaders = {
              'Authorization': 'Bearer ${credential.accessToken}',
            };

            final baseClient = AuthenticatedClient(client, authHeaders);
            CalendarClient.calendar = gcal.CalendarApi(baseClient);
            final calendarListResource = CalendarClient.calendar?.calendarList;
            calendarList = (await calendarListResource?.list())!;
            calendarList.items?.forEach((element) {
              setState(() {
                categories.add(element.summary ?? "");
                categorieIds.add(element.id ?? "");
                if (resultValue["category"] != Null
                    && element.summary == resultValue["category"]) {
                  resultValue["categoryId"] = element.id;
                }
              });
            });

            firebaseUser = await FirebaseAuth.instance.signInWithCredential(credential);
            debugPrint(firebaseUser.user?.uid);
            debugPrint(firebaseUser.user?.email);
          } on PlatformException catch (e) {
            debugPrint(e.message);
          }
      } else {
        debugPrint("No Google User");
        await googleSignIn.signIn();
      }
    });
    if (googleSignIn.currentUser == null) {
      debugPrint("No Google User");
      try {
        await googleSignIn.signIn();
      } on PlatformException catch(e) {
        debugPrint(e.message);
      }
    }
  }

  DateTime combinedDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GlobalVars>(
        create: (_) => GlobalVars(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
          ),
          body: Consumer<GlobalVars>(
              builder: (_, globalVars, __) => Center(
                    child: globalVars.hasResult
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Text(
                                '정보가 정확한가요?',
                              ),
                              SlotEditor(resultValue, CalendarClient.calendar, categories, categorieIds, (DateTime date, TimeOfDay stime, etime, String category, categoryId, title) {
                                resultValue["date"] = date;
                                resultValue["stime"] = stime;
                                resultValue["etime"] = etime;
                                resultValue["category"] = category;
                                resultValue["categoryId"] = categoryId;
                                resultValue["title"] = title;
                              }),
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    debugPrint("Add To Schedule");
                                    debugPrint("CAPI: ${CalendarClient.calendar.toString()}");
                                    resultValue["categoryId"] = categorieIds[categories.indexOf(resultValue["category"])];

                                    // 다음날까지 이어지는 계획일 경우 처리
                                    DateTime endDate = resultValue["date"];
                                    TimeOfDay startTime = resultValue["stime"], endTime = resultValue["etime"];
                                    DateTime t1 = DateTime(endDate.year, endDate.month, endDate.day, startTime.hour, startTime.minute);
                                    DateTime t2 = DateTime(endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute);
                                    if (t1.isAfter(t2)) {
                                      endDate = endDate.add(const Duration(days:1));
                                    }

                                    await CalendarClient.insert(
                                        categoryId: resultValue["categoryId"] ??
                                            '',
                                        title: resultValue["title"] ?? '',
                                        description: '',
                                        location: '',
                                        attendeeEmailList: [],
                                        shouldNotifyAttendees: false,
                                        startTime: combinedDateTime(
                                            resultValue["date"],
                                            resultValue["stime"]),
                                        endTime: combinedDateTime(
                                            endDate,
                                            resultValue["etime"]));
                                  } on PlatformException catch(e) {
                                    debugPrint(e.message);
                                  } finally {
                                    globalVars.setHasResult(false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 10.0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                                child: const Text('스케쥴 추가하기'),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Text(
                                '이렇게 말씀 하신게 맞나요?',
                              ),
                              Padding(
                                padding: EdgeInsets.all(25),
                                child: Text(
                                  widget.sttValues.lastWords.isEmpty && widget.sttValues.onListen ? "듣고 있는중..." : widget.sttValues.lastWords,
                                  style:
                                    Theme.of(context).textTheme.headlineSmall,
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  /*
                                  이전 버전에서 파이어베이스를 통해서 서버쪽 슬롯필링과 NER 결과를 가져올 때 사용하던 코드
                                  final uid = firebaseUser.user?.uid;
                                  debugPrint(uid);
                                  FirebaseDatabaseTools fdbt =
                                      FirebaseDatabaseTools(
                                          context, "mysec", uid!, (Map<dynamic, dynamic> value) {
                                            resultValue = value;
                                            DateFormat format = DateFormat('yyyy-MM-dd');
                                            resultValue["date"] = format.parse(resultValue["date"]);
                                            resultValue["stime"] = TimeOfDay.fromDateTime(DateTime.parse(resultValue["stime"]+":00"));
                                            resultValue["etime"] = TimeOfDay.fromDateTime(DateTime.parse(resultValue["etime"]+":00"));
                                            calendarList.items?.forEach((element) {
                                              setState(() {
                                                if (resultValue["category"] != Null &&
                                                    element.summary ==
                                                        resultValue["category"]) {
                                                  resultValue["categoryId"] =
                                                      element.id;
                                                }
                                              });
                                    });
                                      });
                                  await fdbt.saveCategories(categories);
                                  await fdbt.send(widget.sttValues.lastWords);
                                  */
                                  String text = widget.sttValues.lastWords;
                                  DateTime now = DateTime.now();
                                  DateFormat formatter = DateFormat('yyyy-MM-dd');
                                  String strToday = formatter.format(now);

                                  String suggest = "아래 문장에서 날짜, 시작시간, 끝시간, 카테고리명, 스케쥴명을 분류해줘. 참고로 오늘 날짜는 $strToday 이고, 이때 날짜는 yyyy-MM-dd 포맷으로 시간은 HH:mm 포맷으로 해줘.";
                                  suggest += "만약 시작 시간이 없으면 12:00으로 처리해주고, 끝시간이 없으면 시작시간에서 30분 뒤의 시간으로 처리해줘.";
                                  debugPrint(suggest);

                                  //테스트를 위해 수동으로 작성하던 문장
                                  //text = "1월 7일 23시부터 2시간동안 JP 카테고리로 동영상누끼2 스케쥴 추가";

                                  Gemini.instance.promptStream(parts: [
                                    Part.text(suggest),
                                    Part.text(text)
                                    ]).listen((value) {
                                      geminiResult += value!.output!;
                                  }).onDone(() {
                                    debugPrint(geminiResult);
                                    List<String> temp = geminiResult.split(
                                        "\n");
                                    List<String> temp2 = [];
                                    int valueIndex = 0;
                                    List<String> valueDefault = [strToday, "12:00", "", categories[0], "내 스케쥴"];
                                    for (String item in temp) {
                                      if (item
                                          .trim()
                                          .isNotEmpty) {
                                        List<String> temp3 = item.split("**:");
                                        if (temp3.length == 1) {
                                          temp3 = item.split(":**");
                                          if (temp3.length == 1) {
                                            temp3 = item.split(":");
                                            if (temp3.length > 2) {
                                              temp3[1] += temp3[2];
                                            }
                                          }
                                        }
                                        String value = temp3[1].trim();
                                        List<String> temp4 = value.split(" ");
                                        if (temp4[0] == "(없음)") {
                                          if (valueIndex != 2) {
                                            temp2.add(valueDefault[valueIndex]);
                                          }
                                        } else {
                                          if (valueIndex == 3 || valueIndex == 4) {
                                            temp2.add(value.trim());
                                          } else {
                                            temp2.add(temp4[0].trim());
                                          }
                                        }
                                      }
                                      valueIndex++;
                                    }
                                    geminiResult = "";
                                    resultValue["date"] = DateTime.parse(temp2[0]);
                                    resultValue["stime"] =
                                        TimeOfDay.fromDateTime(DateTime.parse(
                                            temp2[0] + " " + temp2[1] + ":00"));
                                    resultValue["etime"] =
                                        TimeOfDay.fromDateTime(DateTime.parse(
                                            temp2[0] + " " + temp2[2] + ":00"));
                                    calendarList.items?.forEach((element) {
                                      setState(() {
                                        if (temp2[3] != Null &&
                                            element.summary?.toUpperCase() == temp2[3].toUpperCase()) {
                                          temp2[3] = element.summary!;
                                          resultValue["category"] = temp2[3];
                                          resultValue["categoryId"] =
                                              element.id;
                                        }
                                      });
                                    });
                                    resultValue["title"] = temp2[4];
                                    globalVars.setHasResult(true);
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 10.0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                                child: const Text('보내기'),
                              ),
                            ],
                          ),
                  )),
          floatingActionButton: FloatingActionButton(
            onPressed: _listenSpeak,
            tooltip: widget.sttValues.onListen ? 'Stop' : 'Listen',
            child: widget.sttValues.onListen
                ? const Icon(Icons.stop)
                : const Icon(Icons.speaker),
          ),
        ));
  }
}
