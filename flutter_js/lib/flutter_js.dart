import 'dart:io';
import 'package:flutter_js/javascript_runtime.dart';

import 'package:flutter_js/javascriptcore/jscore_runtime.dart';

import 'quickjs/quickjs_runtime2.dart';

export 'package:flutter_js_platform_interface/js_eval_result.dart';
export 'javascript_runtime.dart';

// import condicional to not import ffi libraries when using web as target
// import "something.dart" if (dart.library.io) "other.dart";
// REF:
// - https://medium.com/flutter-community/conditional-imports-across-flutter-and-web-4b88885a886e
// - https://github.com/creativecreatorormaybenot/wakelock/blob/master/wakelock/lib/wakelock.dart
JavascriptRuntime getJavascriptRuntime() {
  JavascriptRuntime runtime;
  if (Platform.isIOS || Platform.isMacOS) {
    runtime = JavascriptCoreRuntime();
  } else {
    runtime = QuickJsRuntime2();
  }
  return runtime;
}
