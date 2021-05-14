import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_js/javascript_runtime.dart';
import 'package:flutter_js/javascriptcore/binding/js_context_ref.dart';
import 'package:flutter_js/javascriptcore/binding/js_object_ref.dart'
    as jsObject;
import 'package:flutter_js/javascriptcore/binding/js_string_ref.dart';
import 'package:flutter_js/javascriptcore/binding/js_value_ref.dart';
import 'package:flutter_js/javascriptcore/flutter_jscore.dart';
import 'package:flutter_js/javascriptcore/jscore/js_value.dart';
import 'package:flutter_js/javascriptcore/jscore_bindings.dart';
import 'package:flutter_js_platform_interface/js_eval_result.dart';

class JavascriptCoreRuntime extends JavascriptRuntime {
  late Pointer _contextGroup;
  late Pointer _globalContext;
  late JSContext context;
  late Pointer _globalObject;

  int executePendingJob() {
    evaluate('(function(){})();');
    return 0;
  }

  String? onMessageFunctionName;
  String? sendMessageFunctionName;

  JavascriptCoreRuntime() {
    _contextGroup = jSContextGroupCreate();
    _globalContext = jSGlobalContextCreateInGroup(_contextGroup, nullptr);
    _globalObject = jSContextGetGlobalObject(_globalContext);

    context = JSContext(_globalContext);

    Pointer<Utf8> channelName = 'FlutterJS'.toNativeUtf8();
    final channelObj = jsObject.jSObjectMake(_globalContext, nullptr, nullptr);
    jsObject.jSObjectSetProperty(
      _globalContext,
      _globalObject,
      jSStringCreateWithUTF8CString(channelName),
      channelObj,
      0,
      nullptr,
    );
    calloc.free(channelName);

    _sendMessageDartFunc = _sendMessage;

    Pointer<Utf8> funcNameCString = 'sendMessage'.toNativeUtf8();
    var functionObject = jSObjectMakeFunctionWithCallback(
        _globalContext,
        jSStringCreateWithUTF8CString(funcNameCString),
        Pointer.fromFunction(sendMessageBridgeFunction));
    jSObjectSetProperty(
        _globalContext,
        channelObj,
        jSStringCreateWithUTF8CString(funcNameCString),
        functionObject,
        jsObject.JSPropertyAttributes.kJSPropertyAttributeNone,
        nullptr);
    calloc.free(funcNameCString);

    init();
  }

  @override
  void initChannelFunctions() {
    JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()] = {};
  }

  @override
  JsEvalResult evaluate(String js, {String? name}) {
    Pointer<Utf8> scriptCString = js.toNativeUtf8();
    Pointer<Utf8>? nameCString = name?.toNativeUtf8();

    JSValuePointer exception = JSValuePointer();
    var jsValueRef = jSEvaluateScript(
        _globalContext,
        jSStringCreateWithUTF8CString(scriptCString),
        name == null ? nullptr : jSStringCreateWithUTF8CString(nameCString!),
        nullptr,
        1,
        exception.pointer);
    calloc.free(scriptCString);
    if(nameCString != null) {
      calloc.free(nameCString);
    }

    String result;

    JSValue exceptionValue = exception.getValue(context);
    bool isPromise = false;
    if (exceptionValue.isObject) {
      result =
          'ERROR: ${exceptionValue.toObject().getProperty("message").string}';
    } else {
      result = _getJsValue(jsValueRef);
      JSValue resultValue = JSValuePointer(jsValueRef).getValue(context);

      isPromise = resultValue.isObject &&
          resultValue.toObject().getProperty('then').isObject &&
          resultValue.toObject().getProperty('catch').isObject;
    }

    return JsEvalResult(
      result,
      exceptionValue.isObject ? exceptionValue.toObject().pointer : jsValueRef,
      isError: result.startsWith('ERROR:'),
      isPromise: isPromise,
    );
  }

  @override
  void dispose() {
    jSContextGroupRelease(_contextGroup);
    super.dispose();
  }

  @override
  String getEngineInstanceId() => hashCode.abs().toString();

  @override
  bool setupBridge(String channelName, dynamic Function(dynamic args) fn) {
    final channelFunctionCallbacks =
        JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()]!;

    if (channelFunctionCallbacks.keys.contains(channelName)) return false;

    channelFunctionCallbacks[channelName] = fn;

    return true;
  }

  static Pointer sendMessageBridgeFunction(
      Pointer ctx,
      Pointer function,
      Pointer thisObject,
      int argumentCount,
      Pointer<Pointer> arguments,
      Pointer<Pointer> exception) {
    if (_sendMessageDartFunc != null) {
      return _sendMessageDartFunc!(
          ctx, function, thisObject, argumentCount, arguments, exception);
    }
    return nullptr;
  }

  String _getJsValue(Pointer jsValueRef) {
    if (jSValueIsNull(_globalContext, jsValueRef) == 1) {
      return 'null';
    } else if (jSValueIsUndefined(_globalContext, jsValueRef) == 1) {
      return 'undefined';
    }
    var resultJsString =
        jSValueToStringCopy(_globalContext, jsValueRef, nullptr);
    var resultCString = jSStringGetCharactersPtr(resultJsString);
    int resultCStringLength = jSStringGetLength(resultJsString);
    if (resultCString == nullptr) {
      return 'null';
    }
    String result = String.fromCharCodes(Uint16List.view(
        resultCString.cast<Uint16>().asTypedList(resultCStringLength).buffer,
        0,
        resultCStringLength));
    jSStringRelease(resultJsString);
    return result;
  }

  static jsObject.JSObjectCallAsFunctionCallbackDart? _sendMessageDartFunc;

  Pointer _sendMessage(
      Pointer ctx,
      Pointer function,
      Pointer thisObject,
      int argumentCount,
      Pointer<Pointer> arguments,
      Pointer<Pointer> exception) {
    String msg = 'No Message';
    if (argumentCount != 0) {
      msg = '';
      for (int i = 0; i < argumentCount; i++) {
        if (i != 0) {
          msg += '\n';
        }
        var jsValueRef = arguments[i];
        msg += _getJsValue(jsValueRef);
      }
    }

    final channelFunctions =
        JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()]!;

    String channelName = _getJsValue(arguments[0]);
    // FIXME: object instead of string
    String message = _getJsValue(arguments[1]);

    if (channelFunctions.containsKey(channelName)) {
      dynamic result = channelFunctions[channelName]!.call(jsonDecode(message));
      if(result is Future) {
        final resolve = jSValueMakeUndefined(_globalContext);
        final reject = jSValueMakeUndefined(_globalContext);
        result.then((value) {
          jsObject.jSObjectCallAsFunction(_globalContext, resolve, resolve, 1, jSValueMakeFromJSONString(_globalContext, JSString.fromString(jsonEncode(result)).pointer), nullptr);
        }).catchError((err) {
          jsObject.jSObjectCallAsFunction(_globalContext, reject, reject, 1, JSString.fromString(err.toString()).pointer, nullptr);
        }).whenComplete(() {
          calloc.free(resolve);
          calloc.free(reject);
        });
        return jsObject.jSObjectMakeDeferredPromise(_globalContext, resolve, reject, nullptr);
      } else {
        return jSValueMakeFromJSONString(_globalContext, JSString.fromString(jsonEncode(result)).pointer);
      }
    } else {
      print('No channel $channelName registered');
    }

    return nullptr;
  }

  @override
  JsEvalResult callFunction(Pointer<NativeType>? fn, Pointer<NativeType>? obj) {
    JSValue fnValue = JSValuePointer(fn).getValue(context);
    JSObject functionObj = fnValue.toObject();
    JSValuePointer exception = JSValuePointer();
    JSValue result = functionObj.callAsFunction(
      functionObj,
      JSValuePointer(obj),
      exception: exception,
    );
    JSValue exceptionValue = exception.getValue(context);
    bool isPromise = false;

    if (exceptionValue.isObject) {
      throw Exception(
          'ERROR: ${exceptionValue.toObject().getProperty("message").string}');
    } else {
      isPromise = result.isObject &&
          result.toObject().getProperty('then').isObject &&
          result.toObject().getProperty('catch').isObject;
    }

    return JsEvalResult(
      _getJsValue(result.pointer),
      exceptionValue.isObject
          ? exceptionValue.toObject().pointer
          : result.pointer,
      isPromise: isPromise,
    );
  }

  @override
  T? convertValue<T>(JsEvalResult jsValue) {
    if (jSValueIsNull(_globalContext, jsValue.rawResult) == 1) {
      return null;
    } else if (jSValueIsString(_globalContext, jsValue.rawResult) == 1) {
      return _getJsValue(jsValue.rawResult) as T;
    } else if (jSValueIsBoolean(_globalContext, jsValue.rawResult) == 1) {
      return (_getJsValue(jsValue.rawResult) == "true") as T;
    } else if (jSValueIsNumber(_globalContext, jsValue.rawResult) == 1) {
      String valueString = _getJsValue(jsValue.rawResult);

      if (valueString.contains(".")) {
        try {
          return double.parse(valueString) as T;
        } on TypeError {
          print('Failed to cast $valueString... returning null');
          return null;
        }
      } else {
        try {
          return int.parse(valueString) as T;
        } on TypeError {
          print('Failed to cast $valueString... returning null');
          return null;
        }
      }
    } else if (jSValueIsObject(_globalContext, jsValue.rawResult) == 1 ||
        jSValueIsArray(_globalContext, jsValue.rawResult) == 1) {
      JSValue objValue = JSValuePointer(jsValue.rawResult).getValue(context);
      String serialized = objValue.createJSONString(null).string!;
      return jsonDecode(serialized);
    } else {
      return null;
    }
  }

  @override
  String jsonStringify(JsEvalResult jsValue) {
    JSValue objValue = JSValuePointer(jsValue.rawResult).getValue(context);
    return objValue.createJSONString(null).string!;
  }

  @override
  Future<JsEvalResult> evaluateAsync(String code) {
    return Future.value(evaluate(code));
  }
}
