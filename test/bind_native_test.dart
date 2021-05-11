import 'dart:io';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JavascriptRuntime jsRuntime;

  setUp(() {
    jsRuntime = getJavascriptRuntime();
  });

  tearDown(() {
    try {
      jsRuntime.dispose();
    } on Error catch (_) {}
  });

  test('echo', () async {
    String input = '';
    jsRuntime.bindNative('echo', (dynamic args) async {
      input = args;
      return Future.delayed(Duration(milliseconds: 500), () => 'Pong!');
    });
    dynamic result = jsRuntime.evaluate(File('test/echo_test.js').readAsStringSync(), name: '<test:echo>').rawResult;
    expect(await result, 'Hello World!');
    expect(input, 'Ping?');
  });
}