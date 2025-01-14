import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js_extension_http/extension.dart';
import 'echo.dart';

class HttpExtensionExample extends StatefulWidget {
  @override
  _HttpExtensionExampleState createState() => _HttpExtensionExampleState();
}

class _HttpExtensionExampleState extends State<HttpExtensionExample> {
  late JavascriptRuntime jsRuntime;
  late TextEditingController sourceController;
  HttpServer? server;
  bool error = false;
  int coast = -1;
  dynamic? response;
  Map<String, String> sources = {
    'GET':
        r'''FlutterJS.send(`__echo__server__/echo?greeting=${encodeURIComponent("Hello World!")}&plugin=${encodeURIComponent("Flutter JS")}`)''',
    'POST FORM':
        r'''FlutterJS.send({url:"__echo__server__", method:"POST",body:{greeting:"Hello World!", plugin: "Flutter JS"}, headers: {"Content-Type":"application/x-www-form-urlencoded"}})''',
    'POST JSON':
        r'''FlutterJS.send({url:"__echo__server__", method:"POST",body:{greeting:"Hello World!", plugin: "Flutter JS"}, headers: {"Content-Type":"application/json;charset=utf-8"}})''',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    sourceController = TextEditingController();
    serve().then((_) {
      server = _;
      String echoServer = 'http://${server!.address.host}:${server!.port}';
      sources.updateAll(
          (key, value) => value.replaceFirst('__echo__server__', echoServer));
      sourceController.text = sources['GET']!;
      if (mounted) {
        setState(() {});
      }
    });

    jsRuntime = getJavascriptRuntime();
    jsRuntime.enableHttpExtension(
        httpClientProvider: () => HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true);
  }

  @override
  void dispose() {
    super.dispose();
    jsRuntime.dispose();
    server?.close();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void evaluate() async {
    int begin = DateTime.now().microsecondsSinceEpoch;
    jsRuntime.dispatch();
    JsEvalResult result =
        jsRuntime.evaluate(sourceController.text, name: '<example>');
    response = result.rawResult is Future
        ? await result.rawResult
        : result.rawResult;
    coast = (DateTime.now().microsecondsSinceEpoch - begin) ~/ 1000;
    jsRuntime.stopDispatch();
    error = result.isError;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              child: TextField(
                minLines: 6,
                maxLines: 16,
                controller: sourceController,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 12.0),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: server == null
                  ? []
                  : sources.keys
                      .map(
                        (_) => ElevatedButton(
                          onPressed: () => sourceController.text = sources[_]!,
                          child: Text(_),
                        ),
                      )
                      .toList(),
            ),
            Padding(
              padding: EdgeInsets.only(top: 12.0),
            ),
            Row(
              children: [
                coast == -1
                    ? SizedBox.shrink()
                    : Padding(
                        padding: EdgeInsets.only(right: 6.0),
                        child: Text('Coast:${coast}ms'),
                      ),
                ElevatedButton(
                  onPressed: () => evaluate(),
                  child: Text('Evaluate'),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 12.0),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.blueGrey,
                child: SingleChildScrollView(
                  child: error
                      ? Text(
                          response.toString(),
                          style: const TextStyle(color: Colors.red),
                        )
                      : ExampleResponseWidget(response),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExampleResponseWidget extends StatelessWidget {
  final response;

  ExampleResponseWidget(this.response);

  @override
  Widget build(BuildContext context) {
    if (response == null) {
      return SizedBox.shrink();
    }
    final Map headers = response['headers'];
    List<String> output = [];
    output.add('> ${response["statusCode"]} ${response["reasonPhrase"]}');
    if (response['persistentConnection'] == true) {
      output.add('> persistent connection');
    }
    if (response['isRedirect'] == true) {
      output.add('> redirected');
      (response['redirects'] as List).forEach((_) => output.add(
          '> redirected to ${_["location"]} with ${_["statusCode"]} ${_["reasonPhrase"]}'));
    }
    headers.forEach((key, value) => output.add('> $key: $value'));
    output.add(response["body"]);
    return Text(output.join('\n'));
  }
}
