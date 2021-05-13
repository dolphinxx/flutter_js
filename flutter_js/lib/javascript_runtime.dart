import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'package:flutter_js_platform_interface/javascript_runtime_interface.dart';

import 'package:flutter_js_platform_interface/js_eval_result.dart';

// class FlutterJsPlatformEmpty extends JavascriptRuntime {
//   @override
//   JsEvalResult callFunction(Pointer<NativeType> fn, Pointer<NativeType> obj) {
//     throw UnimplementedError();
//   }
//
//   @override
//   T? convertValue<T>(JsEvalResult jsValue) {
//     throw UnimplementedError();
//   }
//
//   @override
//   void dispose() {}
//
//   @override
//   JsEvalResult evaluate(String code, {String? name}) {
//     throw UnimplementedError();
//   }
//
//   @override
//   Future<JsEvalResult> evaluateAsync(String code) {
//     throw UnimplementedError();
//   }
//
//   @override
//   int executePendingJob() {
//     throw UnimplementedError();
//   }
//
//   @override
//   String getEngineInstanceId() {
//     throw UnimplementedError();
//   }
//
//   @override
//   void initChannelFunctions() {
//     throw UnimplementedError();
//   }
//
//   @override
//   String jsonStringify(JsEvalResult jsValue) {
//     throw UnimplementedError();
//   }
//
//   @override
//   bool setupBridge(String channelName, void Function(dynamic args) fn) {
//     throw UnimplementedError();
//   }
// }

abstract class JavascriptRuntime implements JavascriptRuntimeInterface {
  static bool debugEnabled = false;
  final List<Function> _extensionDisposeCallbacks = [];

  @protected
  JavascriptRuntime init() {
    evaluate('const FlutterJS = {};void(0)');
    initChannelFunctions();
    _setupDispatch();
    _setupConsoleLog();
    _setupSetTimeout();
    return this;
  }

  Map<String, dynamic> localContext = {};

  Map<String, dynamic> dartContext = {};

  void dispose() {
    if(_extensionDisposeCallbacks.isNotEmpty) {
      _extensionDisposeCallbacks.forEach((callback) {
        try{
          callback();
        } catch(err, stackTrace) {
          print('Exception occurred while calling extension dispose callback.\n$err\n$stackTrace');
        }
      });
      _extensionDisposeCallbacks.clear();
    }
  }

  @override
  void addExtensionDisposeCallback(Function callback) {
    _extensionDisposeCallbacks.add(callback);
  }

  static Map<String, Map<String, Function(dynamic arg)>>
      _channelFunctionsRegistered = {};

  static Map<String, Map<String, Function(dynamic arg)>>
      get channelFunctionsRegistered => _channelFunctionsRegistered;

  JsEvalResult callFunction(Pointer fn, Pointer obj);

  String jsonStringify(JsEvalResult jsValue);

  @protected
  void initChannelFunctions();

  void dispatch([int? interval]) {

  }

  void stopDispatch() {

  }

  void _setupDispatch() {
    evaluate(r'''
    FlutterJS.dispatch = (interval) => FlutterJS.sendMessage("flutter_js::dispatch", interval||100);void(0)
    ''', name: '<dispatch setup>');
    onMessage('flutter_js::dispatch', (dynamic args) {
      dispatch(args??100);
    });
  }

  bool _nativeBound = false;

  @override
  void bindNative(String channelName, FutureOr<dynamic> handler(dynamic args)) {
    if(!_nativeBound) {
      const String source = r'''
FlutterJS.nativeCallbacks = {};
FlutterJS.nativeCallbacksIncrement = 0;
FlutterJS.callNative = async function (channelName, args) {
    const callbackId = FlutterJS.nativeCallbacksIncrement++;
    const promise = new Promise((resolve) => {
        FlutterJS.nativeCallbacks[callbackId] = function() {
            delete FlutterJS.nativeCallbacks[callbackId];
            // console.log(`console:${JSON.stringify(arguments)}`);
            resolve(...arguments);
        };
    });
    FlutterJS.sendMessage(`bind_native::${channelName}`, {"message": JSON.stringify(args), "callback": callbackId});
    return promise;
};
// prevent callNative to be leak.
void(0);
''';
      evaluate(source, name: '<bind_native setup>');
      _nativeBound = true;
    }
    onMessage('bind_native::$channelName', (args) {
      String message = args['message'];
      int jsCallbackId = args['callback'];
      var result = handler(jsonDecode(message));
      // print('callNative[$channelName]: $result');
      var cb = (dynamic result) => evaluate('FlutterJS.nativeCallbacks[$jsCallbackId](${jsonEncode(result)});void(0)', name: '<callNative[$channelName] callback>');
      if(result is Future) {
        result.then(cb);
      } else {
        cb(result);
      }
    });
  }

  void _setupConsoleLog() {
    evaluate("""
    const console = {
      log: function() {
        FlutterJS.sendMessage('ConsoleLog', ['log', [...arguments].join(', ')]);
      },
      warn: function() {
        FlutterJS.sendMessage('ConsoleLog', ['info', [...arguments].join(', ')]);
      },
      error: function() {
        FlutterJS.sendMessage('ConsoleLog', ['error', [...arguments].join(', ')]);
      }
    };void(0)""", name: '<consoleLog setup>');
    onMessage('ConsoleLog', (dynamic args) {
      print(args[1]);
    });
  }

  void _setupSetTimeout() {
    evaluate("""
      var __NATIVE_FLUTTER_JS__setTimeoutCount = -1;
      var __NATIVE_FLUTTER_JS__setTimeoutCallbacks = {};
      function setTimeout(fnTimeout, timeout) {
        // console.log('Set Timeout Called');
        try {
        __NATIVE_FLUTTER_JS__setTimeoutCount += 1;
          var timeoutIndex = '' + __NATIVE_FLUTTER_JS__setTimeoutCount;
          __NATIVE_FLUTTER_JS__setTimeoutCallbacks[timeoutIndex] =  fnTimeout;
          ;
          // console.log(typeof(sendMessage));
          // console.log('BLA');
          FlutterJS.sendMessage('SetTimeout', { timeoutIndex, timeout});
        } catch (e) {
          console.error('ERROR HERE',e.message);
        }
      };
      void(0)
    """, name: '<setTimeout setup>');
    //print('SET TIMEOUT EVAL RESULT: $setTImeoutResult');
    onMessage('SetTimeout', (dynamic args) {
      try {
        int duration = args['timeout'];
        String idx = args['timeoutIndex'];

        Timer(Duration(milliseconds: duration), () {
          evaluate("""
            __NATIVE_FLUTTER_JS__setTimeoutCallbacks[$idx].call();
            delete __NATIVE_FLUTTER_JS__setTimeoutCallbacks[$idx];
          """, name: '<setTimeout callback>');
        });
      } on Exception catch (e) {
        print('Exception no setTimeout: $e');
      } on Error catch (e) {
        print('Erro no setTimeout: $e');
      }
    });
  }

  sendMessage({
    required String channelName,
    required List<String> args,
    String? uuid,
  }) {
    if (uuid != null) {
      evaluate(
          "DART_TO_QUICKJS_CHANNEL_sendMessage('$channelName', '${jsonEncode(args)}', '$uuid');", name: '<sendMessage>');
    } else {
      evaluate(
          "DART_TO_QUICKJS_CHANNEL_sendMessage('$channelName', '${jsonEncode(args)}');", name: '<sendMessage>');
    }
  }

  onMessage(String channelName, void Function(dynamic args) fn) {
    setupBridge(channelName, fn);
  }

  bool setupBridge(String channelName, void Function(dynamic args) fn);

  String getEngineInstanceId();
}
