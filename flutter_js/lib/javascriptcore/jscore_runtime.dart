import 'dart:async';
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
import 'package:flutter_js/javascriptcore/flutter_jscore.dart' hide JSType;
import 'package:flutter_js/javascriptcore/jscore_bindings.dart';
import 'package:flutter_js_platform_interface/js_eval_result.dart';

part 'wrapper.dart';

class JavascriptCoreRuntime extends JavascriptRuntime {
  late Pointer _contextGroup;
  late Pointer _globalContext;
  late JSContext context;

  int executePendingJob() {
    // The ContextGroup handles event loop automatically.
    return 0;
  }

  String? onMessageFunctionName;
  String? sendMessageFunctionName;

  JavascriptCoreRuntime() {
    _contextGroup = jSContextGroupCreate();
    _globalContext = jSGlobalContextCreateInGroup(_contextGroup, nullptr);

    context = JSContext(_globalContext);
    init();
  }

  @override
  void initChannelFunctions() {
    String instanceId = getEngineInstanceId();
    setupChannelFunctions(instanceId, _globalContext);
  }

  static void setupChannelFunctions(dynamic instanceId, Pointer context) {
    JavascriptRuntime.channelFunctionsRegistered[instanceId] = {};

    // Inject engineInstanceId, and obtain FlutterJS reference.
    final channelObj = jsEval(context, 'FlutterJS.instanceId="$instanceId";FlutterJS', name: 'instanceId setup');

    // Define FlutterJS.sendMessage.
    Pointer<Utf8> funcNameCString = 'sendMessage'.toNativeUtf8();
    var functionObject = jSObjectMakeFunctionWithCallback(
        context,
        jSStringCreateWithUTF8CString(funcNameCString),
        Pointer.fromFunction(sendMessageBridgeFunction));
    jSObjectSetProperty(
        context,
        channelObj,
        jSStringCreateWithUTF8CString(funcNameCString),
        functionObject,
        jsObject.JSPropertyAttributes.kJSPropertyAttributeNone,
        nullptr);
    calloc.free(funcNameCString);
  }

  @override
  JsEvalResult evaluate(String js, {String? name}) {
    final jsValueRef;
    try {
      jsValueRef = jsEval(_globalContext, js, name: name);
      final result = jsToDart(_globalContext, jsValueRef);
      return JsEvalResult(null, result, isError: false, isPromise: result is Future);
    }catch(error) {
      return JsEvalResult(null, error, isError: true);
    }
  }

  @override
  void dispose() {
    jSContextGroupRelease(_contextGroup);
    _jsToNativeCallbacks.remove(getEngineInstanceId());
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

  /// Static function for handling FlutterJS.sendMessage call.
  static Pointer sendMessageBridgeFunction(
      Pointer ctx,
      Pointer function,
      Pointer thisObject,
      int argumentCount,
      Pointer<Pointer> arguments,
      Pointer<Pointer> exception) {

    String channelName = jsToDart(ctx, arguments[0]);

    dynamic message = jsToDart(ctx, arguments[1]);
    // Channel names for internal usage(ie: promise and dart2js function callback).
    if(channelName == 'internal::native_callback') {
      final callback = _getNativeCallback(message['instanceId']??getInstanceIdFromContext(ctx), (message['id'] as double).toInt());
      if(callback == null) {
        return nullptr;
      }
      // The thisObject here is always `FlutterJS` when calling `FlutterJS.sendMessage(...)`
      //
      // final globalThis = jSContextGetGlobalObject(ctx);
      // dynamic thisObj = globalThis.address == thisObject.address ? null : jsToDart(ctx, thisObject);
      // return Function.apply(callback, message['args']??[], {if(thisObj != null) #thisObject: thisObject});
      return Function.apply(callback, message['args']??[]);
    }

    String instanceId = getInstanceIdFromContext(ctx);
    final channelFunctions =
    JavascriptRuntime.channelFunctionsRegistered[instanceId]!;

    if (channelFunctions.containsKey(channelName)) {
      dynamic result = channelFunctions[channelName]!.call(jsonDecode(message));
      return dartToJs(ctx, result);
    }

    print('No channel $channelName registered');
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

  @override
  JsEvalResult callFunction(Pointer<NativeType>? fn, Pointer<NativeType>? obj) {
    // FIXME: Replace with jsCallFunction.
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
    // FIXME: Replace with jsToDart.
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
    // FIXME: remove this function
    // JSValue objValue = JSValuePointer(jsValue.rawResult).getValue(context);
    // return objValue.createJSONString(null).string!;
    throw UnsupportedError('Prefer to JSON stringify in js side.');
  }

  @override
  Future<JsEvalResult> evaluateAsync(String code) {
    return Future.value(evaluate(code));
  }
}
