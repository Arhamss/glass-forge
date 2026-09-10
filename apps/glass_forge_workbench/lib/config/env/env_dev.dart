import 'package:envied/envied.dart';

part 'env_dev.g.dart';

@Envied(path: 'env/.env.development')
abstract class EnvDev {
  @EnviedField(varName: 'BASE_URL')
  static const String baseUrl = _EnvDev.baseUrl;

  @EnviedField(varName: 'API_VERSION')
  static const String apiVersion = _EnvDev.apiVersion;

  @EnviedField(varName: 'MAPBOX_API_KEY', obfuscate: true)
  static final String mapboxApiKey = _EnvDev.mapboxApiKey;

  @EnviedField(varName: 'STRIPE_PUBLISHABLE_KEY', obfuscate: true)
  static final String stripePublishableKey = _EnvDev.stripePublishableKey;

  @EnviedField(varName: 'GOOGLE_CLIENT_ID')
  static const String googleClientId = _EnvDev.googleClientId;

  @EnviedField(varName: 'SOCKET_URL')
  static const String socketUrl = _EnvDev.socketUrl;
}
