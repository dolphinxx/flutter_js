type FlutterJSCore = {
  sendMessage(channelName:string, args:any): void;
  callNative<T>(channelName:string, args:any): Promise<T>;
};
type FlutterJSExtensionFoo = {
  // Define extension js function types here.
  greeting(name:string): Promise<string>;
};
declare var FlutterJS:FlutterJSCore&FlutterJSExtensionFoo;