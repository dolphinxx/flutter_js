import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js_example/ajv_example.dart';
import 'package:flutter_js_example/extension/http.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldState = GlobalKey();
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

  String evalJS() {
    String jsResult = javascriptRuntime.evaluate(r"""
            if (typeof MyClass == 'undefined') {
              var MyClass = class {
                constructor(id) {
                  this._id = id;
                }

                get id() => this._id;

                set id(id) => this._id = id;
              }
            }
            var obj = new MyClass(1);
            JSON.stringify({
              "object": JSON.stringify(obj),
              "Math.random": Math.random(),
              "now": new Date(),
              "eval('1+1')": eval("1+1"),
              "RegExp": `"Hello World!".match(new RegExp('world', 'i')) => ${"Hello World!".match(new RegExp('world', 'i'))}`, 
              "decodeURIComponent": decodeURIComponent("https://github.com/abner/flutter_js/issues?q=is%3Aissue+is%3Aopen+comments%3A%3E50"),
              "encodeURIComponent": ["Hello World", "世界你好", "مرحبا بالعالم", "こんにちは世界"].map(_ => `${_} => ${encodeURIComponent(_)}`).join(', '),
            }, null, 2);
            """).stringResult;
    return jsResult;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  dispose() {
    super.dispose();
    javascriptRuntime.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlutterJS Example'),
      ),
      body: Padding(
        padding: EdgeInsets.all(6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'JS Evaluate Result:\n\n$_jsResult\n',
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.only(top: 20),),
            Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                  'Click on the big JS Yellow Button to evaluate the expression using the flutter_js plugin'),
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
            const Padding(padding: EdgeInsets.only(top: 20),),
            ElevatedButton(
              child: const Text('HTTP Extension'),
              onPressed: () => Navigator.of(context).push(PageRouteBuilder(pageBuilder: (ctx, _, __) => HttpExtensionExample())),
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
