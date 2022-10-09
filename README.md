a web dev proxy server that has implement request cors and cookie cors, base on shelf_proxy

## Features

* Modify response headers and cookie for cors in web dev

## Getting started

### step1

Define your target host and local proxy host and port in a dart file ,just like :

```dart
class LocalProxyConfig{
  
  static  String targetUrl = 'https://navi-api.xxx.tech';
  static const String localHost = 'localhost';
  static const int localPort = 8033;

  static const String localProxyUrlWeb = "http://$localHost:$localPort";

}
```

### step2

define a main method in another dart file:

```dart
import 'package:web_dev_proxy/src/shelf_proxy_for_web_dev.dart';

import 'proxy_web_local_config.dart';

Future<void> main() async {
  await startLocalProxyServerForWebDebug(LocalProxyConfig.localHost,LocalProxyConfig.localPort,LocalProxyConfig.targetUrl);
}
```

### step3 

Run the main method in step2

### step4 

use *LocalProxyConfig.localProxyUrlWeb* as your base url in project when platform is web.



#  what did we do in the proxy

### add header to allow  request cros

> just like what you will do in nginx when release in web

```dart
// 添加上跨域的这几个header
// 这里设置请求策略，允许所有
server.defaultResponseHeaders.add('Access-Control-Allow-Origin', '*');
server.defaultResponseHeaders.add('Access-Control-Allow-Credentials', true);
server.defaultResponseHeaders.add('Access-Control-Allow-Headers', '*');
server.defaultResponseHeaders.add('Access-Control-Max-Age', 36000); //加这个是为了不会每次都检测跨域，然后总会有两次请求
server.defaultResponseHeaders.add('Access-Control-Expose-Headers', '*'); //加这个是为了能获取header里面的其他项
```

### modify set-cookie header 

```dart
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
```

# Thanks

https://pub.dev/packages/shelf_proxyfrom the package authors, and more.
