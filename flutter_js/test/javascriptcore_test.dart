import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'package:flutter_js/javascriptcore/binding/js_context_ref.dart';
import 'package:flutter_js/javascriptcore/binding/js_object_ref.dart';
import 'package:flutter_js/javascriptcore/binding/js_value_ref.dart';
import 'package:flutter_js/javascriptcore/jscore_runtime.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Pointer contextGroup;
  late Pointer context;
  setUp(() {
    contextGroup = jSContextGroupCreate();
    context = jSGlobalContextCreateInGroup(contextGroup, nullptr);
    jsEval(context, 'const FlutterJS = {typeOf:function(obj){return typeof obj}}');
  });

  tearDown(() {
    jSGlobalContextRelease(context);
    jSContextGroupRelease(contextGroup);
    // clearAllNativeCallbacks();
  });

  test('get variable', () {
    final ptr = jsEval(context, 'const Foo = 123;Foo');
    expect(jsToDart(context, ptr), 123.0);
  });

  test('typeof', () {
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf(()=>null)')), 'function');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf(null)')), 'object');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf(undefined)')), 'undefined');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf(1)')), 'number');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf(1.1)')), 'number');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf(Infinity)')), 'number');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf(NaN)')), 'number');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf(Math.PI)')), 'number');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf("FlutterJS")')), 'string');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf(true)')), 'boolean');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf({})')), 'object');
    expect(jsToDart(context, jsEval(context, 'FlutterJS.typeOf([])')), 'object');
  });

  test('int to js', () {
    final root = jsEval(context, 'const Test = {};Test');
    final value = dartToJs(context, 100);
    jSObjectSetProperty(context, root, dartToJs(context, 'value'), value, 0, nullptr);
    final result = jsEval(context, r'''Test.value === 100''');
    final actual = jsToDart(context, result);
    expect(actual, isTrue);
  });

  test('double to js', () {
    final root = jsEval(context, 'const Test = {};Test');
    final value = dartToJs(context, 100.1);
    jSObjectSetProperty(context, root, dartToJs(context, 'value'), value, 0, nullptr);
    final result = jsEval(context, r'''Test.value === 100.1''');
    final actual = jsToDart(context, result);
    expect(actual, isTrue);
  });

  test('string to js', () {
    final root = jsEval(context, 'const Test = {};Test');
    final value = dartToJs(context, 'FlutterJS');
    jSObjectSetProperty(context, root, dartToJs(context, 'value'), value, 0, nullptr);
    final result = jsEval(context, r'''Test.value === "FlutterJS"''');
    final actual = jsToDart(context, result);
    expect(actual, isTrue);
  });

  test('bool to js', () {
    final root = jsEval(context, 'const Test = {};Test');
    final _true = dartToJs(context, true);
    final _false = dartToJs(context, false);
    jSObjectSetProperty(context, root, dartToJs(context, '_true'), _true, 0, nullptr);
    jSObjectSetProperty(context, root, dartToJs(context, '_false'), _false, 0, nullptr);
    final result = jsEval(context, r'''Test._true === true && Test._false === false''');
    final actual = jsToDart(context, result);
    expect(actual, isTrue);
  });

  test('List to js', () {
    final root = jsEval(context, 'const Test = {};Test');
    final value = dartToJs(context, [1, 2.1, "FlutterJS", true, false]);
    jSObjectSetProperty(context, root, dartToJs(context, 'value'), value, 0, nullptr);
    final result = jsEval(context, r'''const v = Test.value;v[0]===1&&v[1]===2.1&&v[2]==="FlutterJS"&&v[3]===true&&v[4]===false''');
    final actual = jsToDart(context, result);
    expect(actual, isTrue);
  });

  test('Map to js', () {
    final root = jsEval(context, 'const Test = {};Test');
    final value = dartToJs(context, {'int':1,'double':2.1,"string":"FlutterJS","bool":true, "array":[1,2]});
    jSObjectSetProperty(context, root, dartToJs(context, 'value'), value, 0, nullptr);
    final result = jsEval(context, r'''const v = Test.value;v["int"]===1&&v["double"]===2.1&&v["string"]==="FlutterJS"&&v["bool"]===true&&v["array"].length===2&&v["array"][0]===1&&v["array"][1]===2''');
    final actual = jsToDart(context, result);
    expect(actual, isTrue);
  });

  test('Uint8List to js', () {
    final root = jsEval(context, 'const Test = {};Test');
    final value = dartToJs(context, Uint8List.fromList([1, 2, 3]));
    jSObjectSetProperty(context, root, dartToJs(context, 'value'), value, 0, nullptr);
    final result = jsEval(context, r'''const v = Test.value;const vv=new Uint8Array(v,0);(v instanceof ArrayBuffer)&&vv.byteLength===3&&vv[0]===1&&vv[1]===2&&vv[2]===3''');
    final actual = jsToDart(context, result);
    expect(actual, isTrue);
  });

  test('future to js', () async {
    final channel = jsEval(context, 'FlutterJS.nativeCallbacks={};FlutterJS.instanceId="test";FlutterJS');
    JavascriptCoreRuntime.setupChannelFunctions('test', context);
    final val = dartToJs(context, Future.value('Hello World!'));
    var exception = calloc<Pointer<Pointer<NativeType>>>();
    jSObjectSetProperty(context, channel, dartToJs(context, 'ff'), val, 0, exception);
    jsThrowOnError(context, exception);
    final result = jsEval(context, '(async function() {return await FlutterJS.ff === "Hello World!"}())');
    final actual = jsToDart(context, result);
    expect(await Future.value(actual), true);
  });

  test('get object property names', () {
    final objPtr = jsEval(context, '({a:1,"b":2,3:30})');
    final propNamesPtr = jSObjectCopyPropertyNames(context, objPtr);
    final propNamesLength = jSPropertyNameArrayGetCount(propNamesPtr);
    List propNames = [];
    for(int i = 0;i < propNamesLength;i++) {
      final propNamePtr = jSPropertyNameArrayGetNameAtIndex(propNamesPtr, i);
      // var ptr = jSStringGetCharactersPtr(propNamePtr);
      // int length = jSStringGetLength(propNamePtr);
      // String propName = String.fromCharCodes(Uint16List.view(ptr.cast<Uint16>().asTypedList(length).buffer, 0, length));
      String propName = jsGetString(propNamePtr)!;
      print(propName);
      propNames.add(propName);
    }
    expect(propNames, ['3', 'a', 'b']);
  });

  test('js primitive to dart', () async {
    expect(jsToDart(context, jsEval(context, '1')), 1.0, reason: 'int');
    expect(jsToDart(context, jsEval(context, '1.1')), 1.1, reason: 'double');
    expect(jsToDart(context, jsEval(context, 'true')), true, reason: 'true');
    expect(jsToDart(context, jsEval(context, 'false')), false, reason: 'false');
    expect(jsToDart(context, jsEval(context, '"FlutterJS"')), 'FlutterJS', reason: 'string');
    expect(jsToDart(context, jsEval(context, 'null')), isNull, reason: 'null');
    expect(jsToDart(context, jsEval(context, 'undefined')), isNull, reason: 'undefined');
  });

  test('js array to dart', () async {
    expect(jsToDart(context, jsEval(context, '[1,"2",true,[3,4]]')), [1,'2',true,[3,4]]);
  });

  test('js simple object to dart', () async {
    expect(jsToDart(context, jsEval(context, '({a:1,b:"2",c:true})')), {'a':1,'b':'2','c':true});
  });

  test('js complicate object to dart', () async {
    expect(jsToDart(context, jsEval(context, '({a:1,b:{c:2, d:[3,"4"]}})')), {'a':1,'b':{'c':2,'d':[3,'4']}});
  });

  test('js promise to dart', () async {
    JavascriptCoreRuntime.setupChannelFunctions('test', context);
    // final result = jsEval(context, r'''new Promise((resolve, reject)=> resolve("Hello World!"))''');
    final result = jsEval(context, r'''(async function(){
      return new Promise((resolve, reject)=> resolve("Hello World!"));
    }())''');
    final actual = jsToDart(context, result);
    expect(await Future.value(actual), 'Hello World!');
  });

  test('js function to dart', () async {
    final ptr = jsEval(context, 'function plus(left, right){return left + right;};plus');
    final fn = jsToDart(context, ptr);
    final actual = (fn as Function)([1, 2]);
    expect(actual, 3);
  });

  test('call function', () {
    final fn = jsEval(context, r'''function greeting(name){return `Hello ${name}!`};greeting''');
    int type = jSValueGetType(context, fn);
    expect(type, 5);
    final result = jSObjectCallAsFunction(context, fn, nullptr, 1, jsCreateArgumentArray([dartToJs(context, 'World')]), nullptr);
    final actual = jsToDart(context, result);
    expect(actual, 'Hello World!');
  });

  test('call arrow function', () {
    final fn = jsEval(context, r'''(name) => {return `Hello ${name}!`}''');
    int type = jSValueGetType(context, fn);
    expect(type, 5);
    final result = jSObjectCallAsFunction(context, fn, nullptr, 1, jsCreateArgumentArray([dartToJs(context, 'World')]), nullptr);
    final actual = jsToDart(context, result);
    expect(actual, 'Hello World!');
  });

  test('promise result', () async {
    JavascriptCoreRuntime.setupChannelFunctions('test', context);
    final promise = jsEval(context, r'''new Promise((resolve, reject) => {resolve('Hello World!')})''');
    final actual = await Future.value(jsToDart(context, promise));
    expect(actual, 'Hello World!');
  });

  test('call native return primitive', () async {
    final fn = jSObjectMakeFunctionWithCallback(context, nullptr, Pointer.fromFunction(fnWithCallbackPrimitive));
    final result = jSObjectCallAsFunction(context, fn, nullptr, 1, jsCreateArgumentArray([dartToJs(context, 'World')]), nullptr);
    final actual = jsToDart(context, result);
    expect(actual, 'Hello World!');
  });

  test('call native return future', () async {
    jsEval(context, 'FlutterJS.nativeCallbacks={}');
    JavascriptCoreRuntime.setupChannelFunctions('test', context);
    final fn = jSObjectMakeFunctionWithCallback(context, nullptr, Pointer.fromFunction(fnWithCallbackFuture));
    final result = jSObjectCallAsFunction(context, fn, nullptr, 1, jsCreateArgumentArray([dartToJs(context, 'World')]), nullptr);
    final actual = jsToDart(context, result);
    expect(await Future.value(actual), 'Hello World!');
  });

  test('call function from dart', () {
    jsEval(context, '''
const a = {
  b: {
    c: [
      {
        plus(left, right){
          return (left + right) * this.d;
        }
      }
    ],
    d: 10
  }
};
    ''');
    var fn = jsEval(context, 'a.b.c[0].plus');
    var thisObj = jsEval(context, 'a.b');
    double result = jsCallFunction(context, fn, thisObject:thisObj, args: [1, 2]);
    expect(result, 30);
  });

  test('call dart made function from dart', () {
    final thisObj = jsEval(context, 'const a = {greeting: "Hola"};a');
    // Make a JS function from dart.
    // See [Pointer.fromFunction] for the limitation:
    // Does not accept dynamic invocations -- where the type of the receiver is
    // [dynamic].
    //
    // If you need to make a JS function invoking dynamic dart function, consider using [bindNative].
    final fn = jSObjectMakeFunctionWithCallback(context, nullptr, Pointer.fromFunction(fnWithCallbackPrimitive));
    final actual = jsCallFunction(context, fn, thisObject: thisObj, args: ['World']);
    expect(actual, 'Hola World!');
  });
}

Pointer<NativeType> fnWithCallbackPrimitive(Pointer<NativeType> context, Pointer<NativeType> function, Pointer<NativeType> thisObject, int argumentCount, Pointer<Pointer<NativeType>> arguments, Pointer<Pointer<NativeType>> exception) {
  String message = jsToDart(context, arguments[0]);
  final globalThis = jSContextGetGlobalObject(context);
  dynamic thisObj = globalThis.address == thisObject.address ? null : jsToDart(context, thisObject);
  String? greeting;
  if(thisObj != null) {
    greeting = (thisObj as Map)['greeting'];
  }
  return dartToJs(context, '${greeting?? "Hello"} $message!');
}

Pointer<NativeType> fnWithCallbackFuture(Pointer<NativeType> context, Pointer<NativeType> function, Pointer<NativeType> thisObject, int argumentCount, Pointer<Pointer<NativeType>> arguments, Pointer<Pointer<NativeType>> exception) {
  String message = jsToDart(context, arguments[0]);
  return dartToJs(context, Future.value('Hello $message!'));
}