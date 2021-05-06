import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js_example/ajv_example.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  GlobalKey<ScaffoldState> scaffoldState = GlobalKey();
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FlutterJsHomeScreen(),
    );
  }
}

class FlutterJsHomeScreen extends StatefulWidget {
  @override
  _FlutterJsHomeScreenState createState() => _FlutterJsHomeScreenState();
}

class _FlutterJsHomeScreenState extends State<FlutterJsHomeScreen> {
  String _jsResult = '';

  final JavascriptRuntime javascriptRuntime = getJavascriptRuntime();

  String? _quickjsVersion;

  Process? _process;
  bool _processInitialized = false;
  String evalJS() {
    String jsResult = javascriptRuntime.evaluate("""
            if (typeof MyClass == 'undefined') {
              var MyClass = class  {
                constructor(id) {
                  this.id = id;
                }
                
                getId() { 
                  return this.id;
                }
              }
            }
            var obj = new MyClass(1);
            var jsonStringified = JSON.stringify(obj);
            var value = Math.trunc(Math.random() * 100).toString();
            JSON.stringify({ "object": jsonStringified, "expression": value});
            """).stringResult;
    return jsResult;
  }

  @override
  void initState() {
    super.initState();
    javascriptRuntime.evaluate(r'''globalThis.$nativeCallbacks = {};
globalThis.$nativeCallbacksIncrement = 0;
async function callNative(channelName, args) {
    const callbackId = globalThis.$nativeCallbacksIncrement++;
    const promise = new Promise((resolve) => {
        globalThis.$nativeCallbacks[callbackId] = function() {
            delete globalThis.$nativeCallbacks[callbackId];
            console.log(`console:${JSON.stringify(arguments)}`);
            resolve(...arguments);
        };
    });
    sendMessage(channelName, JSON.stringify({"message": JSON.stringify(args), "callback": callbackId}));
    return promise;
}''');
    bindJs('getData', (args) => 'Nothing.');
    // widget.javascriptRuntime.onMessage('ConsoleLog2', (args) {
    //   print('ConsoleLog2 (Dart Side): $args');
    //   return json.encode(args);
    // });
  }

  void ensurePendingJobs(JavascriptRuntime jsRuntime, int interval) {
    Future.delayed(Duration(milliseconds: 100), () {
      int result = jsRuntime.executePendingJob();
      print('executePendingJob:$result');
      if(result > 0) {
        ensurePendingJobs(jsRuntime, interval + 100);
      }
    });
  }
  void bindJs(String channelName, FutureOr<dynamic> handler(dynamic args)) {
    javascriptRuntime.onMessage(channelName, (args) {
      String message = args['message'];
      int jsCallbackId = args['callback'];
      var result = handler(jsonDecode(message));
      print('$channelName result: $result');
      var cb = (dynamic result) => javascriptRuntime.evaluate('globalThis.\$nativeCallbacks[$jsCallbackId](${jsonEncode(result)})');
      if(result is Future) {
        result.then(cb);
      } else {
        cb(result);
      }
      ensurePendingJobs(javascriptRuntime, 100);
    });
  }

  @override
  dispose() {
    super.dispose();
    //widget.javascriptRuntime.dispose();
    javascriptRuntime.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlutterJS Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'JS Evaluate Result:\n\n$_jsResult\n',
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: 20,
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                  'Click on the big JS Yellow Button to evaluate the expression bellow using the flutter_js plugin'),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Math.trunc(Math.random() * 100).toString();",
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AjvExample(
                      //widget.javascriptRuntime,
                      javascriptRuntime),
                ),
              ),
              child: const Text('See Ajv Example'),
            ),
            SizedBox.fromSize(size: Size(double.maxFinite, 20)),
            ElevatedButton(
              child: const Text('Fetch Remote Data'),
              onPressed: () async {
                var asyncResult = await javascriptRuntime.evaluateAsync("""
                callNative('getData', 'Anything?');
              """);
                javascriptRuntime.executePendingJob();
                // final promiseResolved =
                //     await javascriptRuntime.handlePromise(asyncResult);
                var result = asyncResult.rawResult is Future ? await asyncResult.rawResult : asyncResult.rawResult;
                setState(() => _quickjsVersion = result.toString());
              },
            ),
            Text(
              'QuickJS Version\n${_quickjsVersion == null ? '<NULL>' : _quickjsVersion}',
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.transparent,
        child: Image.asset('assets/js.ico'),
        onPressed: () {
          setState(() {
            // _jsResult = widget.evalJS();
            // Future.delayed(Duration(milliseconds: 599), widget.evalJS);
            _jsResult = evalJS();
            Future.delayed(Duration(milliseconds: 599), evalJS);
          });
        },
      ),
    );
  }
}
