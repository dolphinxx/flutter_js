
import 'dart:async';
import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter/services.dart' show rootBundle;

extension BindNative on JavascriptRuntime {
  Future<JavascriptRuntime> enableBindNative() async {
    evaluate(await rootBundle.loadString('packages/flutter_js/assets/js/bind-native.js'));
    return this;
  }

  void bindNative(String channelName, FutureOr<dynamic> handler(dynamic args)) {
    onMessage(channelName, (args) {
      String message = args['message'];
      int jsCallbackId = args['callback'];
      var result = handler(jsonDecode(message));
      print('callNative[$channelName]: $result');
      var cb = (dynamic result) => evaluate('__nativeCallbacks__[$jsCallbackId](${jsonEncode(result)})');
      if(result is Future) {
        result.then(cb);
      } else {
        cb(result);
      }
      ensurePendingJob(100, 100);
    });
  }
}