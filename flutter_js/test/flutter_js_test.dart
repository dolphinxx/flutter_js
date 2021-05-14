import 'dart:convert';
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JavascriptRuntime jsRuntime;

  String loadFile(String name) {
    return File('test_resources/$name').readAsStringSync();
  }

  setUp(() {
    jsRuntime = getJavascriptRuntime();
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

  test('setupBridge', () async {
    jsRuntime.dispatch();
    jsRuntime.setupBridge('foo1', (args) => '$args boom!');
    jsRuntime.setupBridge('foo2', (args) => Future.value('$args boom!'));
    expect(jsRuntime.evaluate('FlutterJS.sendMessage("foo", "222")').rawResult, null);
    expect(jsRuntime.evaluate('FlutterJS.sendMessage("foo1", "222")').rawResult, '222 boom!');
    expect(await jsRuntime.evaluate('FlutterJS.sendMessage("foo2", "222")').rawResult, '222 boom!');
  });

  test('scrape list', () async {
    jsRuntime.dispatch();
    JsEvalResult result = await jsRuntime.evaluateAsync(loadFile('extract_list_test.js'));
    var expected = jsonDecode(loadFile('extract_list_expected.json'));
    expect(await result.rawResult, expected);
  });
}
