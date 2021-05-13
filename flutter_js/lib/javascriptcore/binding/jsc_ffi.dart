import 'dart:ffi';
import 'dart:io';

DynamicLibrary? _jscLib;

DynamicLibrary? get jscLib {
  if (_jscLib != null) {
    return _jscLib;
  }
  _jscLib = Platform.isAndroid
      ? DynamicLibrary.open("libjsc.so")
      : Platform.isIOS || Platform.isMacOS
          ? DynamicLibrary.open("JavaScriptCore.framework/JavaScriptCore")
          : null;
  return _jscLib;
}
