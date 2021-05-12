import 'dart:async';

import 'js_eval_result.dart';

abstract class JavascriptRuntimeInterface {
  JsEvalResult evaluate(String code, {String? name});

  Future<JsEvalResult> evaluateAsync(String code);

  void bindNative(String channelName, FutureOr<dynamic> handler(dynamic args));

  int executePendingJob();

  /// Start event loop in [interval] ms, multiple access safety.
  void dispatch(int interval);

  void stopDispatch();

  onMessage(String channelName, void Function(dynamic args) fn);

  sendMessage({
    required String channelName,
    required List<String> args,
    String? uuid,
  });

  T? convertValue<T>(JsEvalResult jsValue);

  void addExtensionDisposeCallback(Function callback);
}