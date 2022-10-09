

import 'package:web_dev_proxy/src/shelf_proxy_for_web_dev.dart';

import 'proxy_web_local_config.dart';

Future<void> main() async {
  await startLocalProxyServerForWebDebug(LocalProxyConfig.localHost,LocalProxyConfig.localPort,LocalProxyConfig.targetUrl);
}
