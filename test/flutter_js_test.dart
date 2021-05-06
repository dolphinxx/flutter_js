import 'dart:convert';
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_js/extensions/bind_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JavascriptRuntime jsRuntime;

  String loadFile(String name) {
    return File('test_resources/$name').readAsStringSync();
  }

  setUp(() {
    jsRuntime = getJavascriptRuntime(xhr: false);
    jsRuntime.enableBindNative();
    jsRuntime.bindNative('loadFile', (dynamic args) {
      return loadFile(args);
    });
  });

  tearDown(() {
    try {
      jsRuntime.dispose();
    } on Error catch (_) {}
  });

  test('evaluate javascript', () {
    final result = jsRuntime.evaluate('Math.pow(5,3)');
    print('${result.rawResult}, ${result.stringResult}');
    print(
        '${result.rawResult.runtimeType}, ${result.stringResult.runtimeType}');
    expect(result.rawResult, equals(125));
    expect(result.stringResult, equals('125'));
  });

  test('bind native', () async {
    jsRuntime.bindNative('getStr', (dynamic args) async {
      print('callNative[getStr] args:${jsonEncode(args)}');
      return File('test_resources/str.txt').readAsString().then((_) => '$args$_');
    });
    jsRuntime.bindNative('add', (dynamic args) {
      print('callNative[add] args:${jsonEncode(args)}');
      return args[0] + args[1];
    });
    jsRuntime.bindNative('time', (dynamic args) {
      print('callNative[time] args:${jsonEncode(args)}');
      return args[0] * args[1];
    });
    dynamic result = jsRuntime.evaluate(loadFile('communicate_test.js')).rawResult;
    expect(await result, 'I have 16 Strawberries.');
    // await Future.delayed(Duration(seconds: 5));
  });
  test('scrape list', () async {
    JsEvalResult result = await jsRuntime.evaluateAsync(loadFile('extract_list_test.js'));
    var expected = jsonDecode(loadFile('extract_list_expected.json'));
    expect(await result.rawResult, expected);
  });
}
