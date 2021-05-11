import 'dart:convert';
import 'dart:io';
import 'request.dart';
import 'cache.dart';
import 'js.dart';
import 'abort_controller.dart';

import 'package:flutter_js_platform_interface/javascript_runtime_interface.dart';

extension HttpExtension on JavascriptRuntimeInterface {
  /// Provider a [httpClientProvider] to have customization of [HttpClient] instance creation.
  ///
  /// If your desired charsets are not appear in [Encoding], provider them through [encodingMap].
  ///
  /// Only error messages are printed if [quiet] is true.
  void enableHttpExtension({HttpClient httpClientProvider()?, Map<String, Encoding>? encodingMap, bool? quiet, CacheProvider? cacheProvider, RequestInterceptor? requestInterceptor, ResponseInterceptor? responseInterceptor}) {
    evaluate(source, name: '<http_client setup>');
    Map<String, Encoding> _encodingMap = encodingMap??{};
    HttpClient? client;
    addExtensionDisposeCallback(() => client?.close(force: true));
    Map<int, AbortController> _abortControllers = {};
    onMessage('http_client::send', (dynamic args) {
      client = client??(httpClientProvider??() => HttpClient())();
      final httpOptions = args['httpOptions']??{};
      final clientOptions = args['clientOptions']??{};
      final requestId = args['id'];
      dynamic _response;
      AbortController _abortController = AbortController();
      _abortControllers[requestId] = _abortController;
      send(client!, httpOptions, clientOptions, cacheProvider: cacheProvider, encodingMap: _encodingMap, abortController: _abortController, requestInterceptor: requestInterceptor, responseInterceptor: responseInterceptor).then<void>((response) {
        _response = response;
      }).catchError((Object err, StackTrace stackTrace) {
        if(err is HttpException) {
          _response = {"statusCode": err is AbortException ? 308 : 0, "reasonPhrase": err.message};
        } else {
          _response = {"statusCode": 0, "reasonPhrase": err.toString()};
          print('Request for ${httpOptions["url"]} failed.\n$err\n$stackTrace');
        }
      }).whenComplete(() {
        _abortControllers.remove(requestId);
        // TODO: Maybe more efficient through callFunction
        final result = evaluate('__flutter_js_extension_http_client__callback__($requestId, ${jsonEncode(_response)})', name: '<http_client response>');
        if(result.isError) {
          print(result.rawResult);
        }
      });
    });
    onMessage('http_client::abort', (dynamic args) {
      _abortControllers[args['id']]?.abort();
    });
  }
}

// http.Request buildRequest(Map httpOptions) {
//   String method = (httpOptions['method'] as String?)?.toUpperCase()??'GET';
//   Uri uri = Uri.parse(httpOptions['url']);
//   http.Request request = http.Request(method, uri);
//   if(httpOptions.containsKey('followRedirects')) {
//     request.followRedirects = parseBool(httpOptions['followRedirects']);
//     if(httpOptions.containsKey('maxRedirects')) {
//       request.maxRedirects = parseInt(httpOptions['maxRedirects']);
//     }
//   }
//   if(httpOptions.containsKey('persistentConnection')) {
//     request.persistentConnection = parseBool(httpOptions['persistentConnection']);
//   }
//   dynamic headers = httpOptions['headers'];
//   // copy headers
//   if(headers != null && headers is Map) {
//     headers.forEach((key, value) {
//       if(value != null) {
//         request.headers[key] = value;
//       }
//     });
//   }
//   if(httpOptions.containsKey('body') && httpOptions['body'] != null) {
//     request.body = httpOptions['body'];
//   }
//   return request;
// }

// bool parseBool(dynamic raw) {
//   if(raw == null) {
//     return false;
//   }
//   return raw == true || raw == 1 || raw == '1' || raw == 'true';
// }
//
// int parseInt(dynamic raw, {int defaultVal = 0}) {
//   if(raw is int) {
//     return raw;
//   }
//   if(raw is String) {
//     return int.tryParse(raw)??defaultVal;
//   }
//   return defaultVal;
// }