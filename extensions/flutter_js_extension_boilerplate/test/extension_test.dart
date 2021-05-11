import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/extension.dart';

void main() {
  test('extension', () async {
    JavascriptRuntime jsRuntime = getJavascriptRuntime();
    jsRuntime.enableFooExtension();
    jsRuntime.dispatch();
    JsEvalResult result = jsRuntime.evaluate('''FlutterJS.greeting("Flutter")''', name: '<test>');
    if(result.isError) {
      throw result.rawResult;
    }
    expect(await result.rawResult, 'Hello! Flutter.');
  });
}