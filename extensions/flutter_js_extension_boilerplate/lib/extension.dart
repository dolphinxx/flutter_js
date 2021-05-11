import 'package:flutter_js_platform_interface/javascript_runtime_interface.dart';

import 'src/js.dart';

extension FooExtension on JavascriptRuntimeInterface {
  void enableFooExtension() {
    evaluate(source, name: '<foo setup>');
    bindNative('foo::greeting', (args) async => 'Hello! $args.');
  }
}