FlutterJS.greeting = async function(name:string):Promise<string> {
  return await FlutterJS.callNative('foo::greeting', name);
};