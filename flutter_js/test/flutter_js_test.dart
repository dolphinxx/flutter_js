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

  test('evaluate javascript', () {
    final result = jsRuntime.evaluate('Math.pow(5,3)');
    print('${result.rawResult}, ${result.stringResult}');
    print(
        '${result.rawResult.runtimeType}, ${result.stringResult.runtimeType}');
    expect(result.rawResult, equals(125.0));
    expect(result.stringResult, equals('125.0'));
  });

  test('async/await', () async {
    final result = jsRuntime.evaluate(r'''
    (async function() {
      async function t(input){
        return new Promise((resolve, reject) => resolve(input + '!'));
      }
      return await t('Hello') + 'World!';
    }())
    ''');
    final actual = await Future.value(result.rawResult);
    expect(actual, 'Hello!World!');
  });

  test('js2dart basic', () {
    expect(jsRuntime.evaluate(r'''({"number":1,boolean:true,string:'Hello World!',array:[1,"2",null],object:{"nested":"yes"}})''').rawResult, {'number':1,'boolean':true,'string':'Hello World!','array':[1,"2",null],'object':{"nested":"yes"}});
  });

  test('js2dart promise', () async {
    expect(await jsRuntime.evaluate(r'''(async function() {return new Promise((resolve, reject) => {resolve("Hello World!!")})}())''').rawResult, 'Hello World!!');
  });

  test('setupBridge missing handler', () async {
    expect(jsRuntime.evaluate('FlutterJS.sendMessage("foo", "0")').rawResult, null);
  });

  test('setupBridge return String', () async {
    jsRuntime.setupBridge('foo', (args) => '$args boom!');
    expect(jsRuntime.evaluate('FlutterJS.sendMessage("foo", "1")').rawResult, '1 boom!');
  });

  test('setupBridge return Promise1', () async {
    jsRuntime.dispatch();
    jsRuntime.setupBridge('foo', (args) => Future.value('$args boom!'));
    expect(await jsRuntime.evaluate('(async function(){return await FlutterJS.sendMessage("foo", "2")}())').rawResult, '2 boom!');
  });

  test('setupBridge return Promise2', () async {
    jsRuntime.dispatch();
    jsRuntime.setupBridge('foo', (args) => Future.value('$args boom!'));
    expect(await jsRuntime.evaluate('FlutterJS.sendMessage("foo", "2")').rawResult, '2 boom!');
  });
}
