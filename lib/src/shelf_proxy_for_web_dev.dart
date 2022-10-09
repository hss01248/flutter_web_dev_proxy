// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// A handler that proxies requests to [url].
///
/// To generate the proxy request, this concatenates [url] and [Request.url].
/// This means that if the handler mounted under `/documentation` and [url] is
/// `http://example.com/docs`, a request to `/documentation/tutorials`
/// will be proxied to `http://example.com/docs/tutorials`.
///
/// [url] must be a [String] or [Uri].
///
/// [client] is used internally to make HTTP requests. It defaults to a
/// `dart:io`-based client.
///
/// [proxyName] is used in headers to identify this proxy. It should be a valid
/// HTTP token or a hostname. It defaults to `shelf_proxy`.
Handler proxyHandler(Object url, {http.Client? client, String? proxyName,
                  Function(http.StreamedResponse)? serverResponseInterceptor}) {
  Uri uri;
  if (url is String) {
    uri = Uri.parse(url);
  } else if (url is Uri) {
    uri = url;
  } else {
    throw ArgumentError.value(url, 'url', 'url must be a String or Uri.');
  }
  final nonNullClient = client ?? http.Client();
  proxyName ??= 'shelf_proxy';

  return (serverRequest) async {
    // TODO(nweiz): Support WebSocket requests.

    // TODO(nweiz): Handle TRACE requests correctly. See
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.8
    final requestUrl = uri.resolve(serverRequest.url.toString());
    final clientRequest = http.StreamedRequest(serverRequest.method, requestUrl)
      ..followRedirects = false
      ..headers.addAll(serverRequest.headers)
      ..headers['Host'] = uri.authority;

    // Add a Via header. See
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.45
    _addHeader(clientRequest.headers, 'via',
        '${serverRequest.protocolVersion} $proxyName');

    // 打印请求参数
   // print("client body: "+clientRequest.sink.toString());


    serverRequest
        .read()
        .forEach(clientRequest.sink.add)
        .catchError(clientRequest.sink.addError)
        .whenComplete(clientRequest.sink.close)
        .ignore();
    final clientResponse = await nonNullClient.send(clientRequest);
    // Add a Via header. See
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.45
    _addHeader(clientResponse.headers, 'via', '1.1 $proxyName');

    // Remove the transfer-encoding since the body has already been decoded by
    // [client].
    clientResponse.headers.remove('transfer-encoding');

    // If the original response was gzipped, it will be decoded by [client]
    // and we'll have no way of knowing its actual content-length.
    if (clientResponse.headers['content-encoding'] == 'gzip') {
      clientResponse.headers.remove('content-encoding');
      clientResponse.headers.remove('content-length');

      // Add a Warning header. See
      // http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.2
      _addHeader(
          clientResponse.headers, 'warning', '214 $proxyName "GZIP decoded"');
    }

    // Make sure the Location header is pointing to the proxy server rather
    // than the destination server, if possible.
    if (clientResponse.isRedirect &&
        clientResponse.headers.containsKey('location')) {
      final location =
      requestUrl.resolve(clientResponse.headers['location']!).toString();
      if (p.url.isWithin(uri.toString(), location)) {
        clientResponse.headers['location'] =
        '/${p.url.relative(location, from: uri.toString())}';
      } else {
        clientResponse.headers['location'] = location;
      }
    }

    serverResponseInterceptor?.call(clientResponse);

    return Response(clientResponse.statusCode,
        body: clientResponse.stream, headers: clientResponse.headers);
  };
}



// TODO(nweiz): use built-in methods for this when http and shelf support them.
/// Add a header with [name] and [value] to [headers], handling existing headers
/// gracefully.
void _addHeader(Map<String, String> headers, String name, String value) {
  final existing = headers[name];
  headers[name] = existing == null ? value : '$existing, $value';
}



Future<void> startLocalProxyServerForWebDebug(String localHost,int localPort,String urlUnderProxy) async {
  var server = await shelf_io.serve(
    proxyHandler(urlUnderProxy,
        serverResponseInterceptor: (clientResponse) {
          transferCookies(clientResponse,localHost);
        }),
    localHost,
    localPort,
  );
  // 添加上跨域的这几个header
  // 这里设置请求策略，允许所有
  server.defaultResponseHeaders.add('Access-Control-Allow-Origin', '*');
  server.defaultResponseHeaders.add('Access-Control-Allow-Credentials', true);
  server.defaultResponseHeaders.add('Access-Control-Allow-Headers', '*');
  server.defaultResponseHeaders.add('Access-Control-Max-Age', 36000); //加这个是为了不会每次都检测跨域，然后总会有两次请求
  server.defaultResponseHeaders.add('Access-Control-Expose-Headers', '*'); //加这个是为了能获取header里面的其他项

  //修改cookie:

  print('Proxying at http://${server.address.host}:${server.port}');
}

void transferCookies(http.StreamedResponse clientResponse,String localHost) {
  String? cookie = clientResponse.headers['set-cookie'];
  if (cookie == null || cookie.isEmpty) {
    return;
  }
//服务器要发送多个 cookie，则应该在同一响应中发送多个 Set-Cookie 标头。
  Cookie cookie2 = Cookie.fromSetCookieValue(cookie);
  cookie2.secure = true;
  cookie2.httpOnly = false;
  cookie2.domain = localHost;
  clientResponse.headers['set-cookie'] = cookie2.toString() + ";SameSite=None;";

  print("reset set-cookie header from $cookie to \n ${clientResponse.headers['set-cookie']}\n");
}
