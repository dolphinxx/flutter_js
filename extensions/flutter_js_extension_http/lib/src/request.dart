import 'dart:convert';
import 'dart:io';
import 'abort_controller.dart';

import 'cache.dart';
import 'response.dart';
import 'media_type.dart';

typedef RequestInterceptor = HttpClientRequest Function(HttpClientRequest request, Map httpOptions, Map clientOptions);
typedef ResponseInterceptor = HttpClientResponse Function(HttpClientResponse response, Map httpOptions, Map clientOptions);

/// The encoding used for the request.
///
/// This encoding is used when converting between [bodyBytes] and [body].
///
/// If the request has a `Content-Type` header and that header has a `charset`
/// parameter, that parameter's value is used as the encoding. Otherwise, if
/// [encoding] has been set manually, that encoding is used. If that hasn't
/// been set either, this defaults to [utf8].
///
/// If the `charset` parameter's value is not a known [Encoding], reading this
/// will throw a [FormatException].
///
/// If the request has a `Content-Type` header, setting this will set the
/// charset parameter on that header.
Encoding getEncoding(MediaType? contentType, Encoding defaultEncoding) {
  if (contentType == null ||
      !contentType.parameters.containsKey('charset')) {
    return defaultEncoding;
  }
  return requiredEncodingForCharset(contentType.parameters['charset']!);
}

/// Returns the [Encoding] that corresponds to [charset].
///
/// Throws a [FormatException] if no [Encoding] was found that corresponds to
/// [charset].
///
/// [charset] may not be null.
Encoding requiredEncodingForCharset(String charset) =>
    Encoding.getByName(charset) ??
        (throw FormatException('Unsupported encoding "$charset".'));

Map<String, String> createHeaders(dynamic raw) {
  Map<String, String> result = {};
  if(raw == null || !(raw is Map)) {
    return result;
  }
  raw.forEach((key, value) {
    if(key == null || value == null) {
      return;
    }
    result[key is String ? key : key.toString()] = value.toString();
  });
  return result;
}

/// Converts a [Map] from parameter names to values to a URL query string.
///
///     mapToQuery({"foo": "bar", "baz": "bang"});
///     //=> "foo=bar&baz=bang"
String mapToQuery(Map map, {Encoding? encoding}) {
  var pairs = <List<String>>[];
  map.forEach((key, value) {
    if(key == null || value == null) {
      return;
    }
    pairs.add([
      Uri.encodeQueryComponent(key.toString(), encoding: encoding ?? utf8),
      Uri.encodeQueryComponent(value.toString(), encoding: encoding ?? utf8)
    ]);
  });
  return pairs.map((pair) => '${pair[0]}=${pair[1]}').join('&');
}

String encodeBody(dynamic body, MediaType? contentType) {
  if(!(body is String)) {
    if(contentType?.mimeType == 'application/x-www-form-urlencoded') {
      return mapToQuery(body);
    }
    if(contentType?.subtype == 'json') {
      return jsonEncode(body);
    }
  }
  return body.toString();
}

Future<NativeResponse> send(HttpClient client, Map httpOptions, Map clientOptions, {CacheProvider? cacheProvider, required Map<String, Encoding> encodingMap, AbortController? abortController, RequestInterceptor? requestInterceptor, ResponseInterceptor? responseInterceptor}) async {
  Uri uri = Uri.parse(httpOptions['url']);
  String method = (httpOptions['method'] as String?)?.toUpperCase()??'GET';
  Map<String, String> requestHeaders = createHeaders(httpOptions['headers']);
  if(cacheProvider != null) {
    NativeResponse? response = cacheProvider.get(uri, method, requestHeaders, clientOptions);
    if(response != null) {
      return response;
    }
  }
  String? contentType = requestHeaders['content-type']??requestHeaders['Content-Type'];
  MediaType? mediaType = contentType == null ? null : MediaType.parse(contentType);

  bool forceEncoding = false;
  Encoding? encoding;
  if(clientOptions.containsKey('encoding') && clientOptions['encoding'].endsWith('!')) {
    // force encoding
    String _encoding = clientOptions['encoding'].substring(0, clientOptions['encoding'].length - 1);
    encoding = encodingMap[_encoding] ?? requiredEncodingForCharset(_encoding);
    forceEncoding = true;
  } else {
    // prefer charset in content-type than encoding in clientOptions.
    String? _encoding = mediaType?.parameters['charset']?? clientOptions['encoding'];
    encoding = _encoding == null ? const Utf8Codec(allowMalformed: true) : encodingMap[_encoding]?? requiredEncodingForCharset(_encoding);
  }

  if(clientOptions.containsKey('connectionTimeout')) {
    client.connectionTimeout = clientOptions['connectionTimeout'];
  }
  if(clientOptions.containsKey('idleTimeout')) {
    client.idleTimeout = clientOptions['idleTimeout'];
  }
  if(clientOptions.containsKey('autoUncompress')) {
    client.autoUncompress = clientOptions['autoUncompress'];
  }
  if(clientOptions.containsKey('followCookies')) {
    // TODO: Auto CookieManager
  }

  if(abortController?.aborted == true) {
    throw AbortException(uri);
  }

  var ioRequest = (await client.openUrl(method, uri));
  abortController?.attach(ioRequest);
  // copy headers
  requestHeaders.forEach((key, value) {
    ioRequest.headers.add(key, value);
  });
  if(httpOptions.containsKey('followRedirects')) {
    ioRequest.followRedirects = parseBool(httpOptions['followRedirects']);
    if(httpOptions.containsKey('maxRedirects')) {
      ioRequest.maxRedirects = parseInt(httpOptions['maxRedirects']);
    }
  }
  if(httpOptions.containsKey('persistentConnection')) {
    ioRequest.persistentConnection = parseBool(httpOptions['persistentConnection']);
  }

  if(httpOptions.containsKey('body') && httpOptions['body'] != null) {
    // add body
    List<int> body = encoding.encode(encodeBody(httpOptions['body'], mediaType));
    ioRequest.contentLength = body.length;
    ioRequest.add(body);
    await ioRequest.flush();
  } else {
    ioRequest.contentLength = 0;
  }
  if(requestInterceptor != null) {
    ioRequest = requestInterceptor(ioRequest, httpOptions, clientOptions);
  }
  HttpClientResponse response = await ioRequest.close();
  if(responseInterceptor != null) {
    response = responseInterceptor(response, httpOptions, clientOptions);
  }
  var responseHeaders = <String, String>{};
  response.headers.forEach((key, values) {
    responseHeaders[key.toLowerCase()] = values.join(',');
  });

  if(!forceEncoding && responseHeaders.containsKey('content-type')) {
    String? responseEncoding = MediaType.parse(responseHeaders['content-type']!).parameters['charset'];
    if(responseEncoding != null) {
      encoding = encodingMap[responseEncoding]?? Encoding.getByName(responseEncoding)??encoding;
    }
  }
  dynamic body = await encoding.decodeStream(response);

  List<EncodableRedirectInfo> redirects = [];
  if(response.redirects.isNotEmpty) {
    Uri last = uri;
    response.redirects.forEach((_) {
      Uri location = _.location.isAbsolute ? _.location : last.resolveUri(_.location);
      last = location;
      redirects.add(EncodableRedirectInfo(_.statusCode, _.method, location));
    });
  }

  NativeResponse result = NativeResponse(
    headers: responseHeaders,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
    statusCode: response.statusCode,
    body: body,
    redirects: redirects,
  );
  cacheProvider?.put(uri, method, requestHeaders, clientOptions, result);
  return result;
}


bool parseBool(dynamic raw) {
  if(raw == null) {
    return false;
  }
  return raw == true || raw == 1 || raw == '1' || raw == 'true';
}

int parseInt(dynamic raw, {int defaultVal = 0}) {
  if(raw is int) {
    return raw;
  }
  if(raw is String) {
    return int.tryParse(raw)??defaultVal;
  }
  return defaultVal;
}