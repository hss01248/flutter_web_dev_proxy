


///define a config class for both  proxy usage and project usage
class LocalProxyConfig{
  static  String targetUrl = 'http://localhost:8088';
  static const String localHost = 'localhost';
  static const int localPort = 8033;

  static const String localProxyUrlWeb = "http://$localHost:$localPort";

}