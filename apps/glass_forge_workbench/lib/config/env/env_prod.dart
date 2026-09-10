import 'package:envied/envied.dart';

part 'env_prod.g.dart';

@Envied(path: 'env/.env.production')
abstract class EnvProd {
  @EnviedField(varName: 'BASE_URL')
  static const String baseUrl = _EnvProd.baseUrl;

  @EnviedField(varName: 'API_VERSION')
  static const String apiVersion = _EnvProd.apiVersion;

  @EnviedField(varName: 'MAPBOX_API_KEY', obfuscate: true)
  static final String mapboxApiKey = _EnvProd.mapboxApiKey;

  @EnviedField(varName: 'STRIPE_PUBLISHABLE_KEY', obfuscate: true)
  static final String stripePublishableKey = _EnvProd.stripePublishableKey;

  @EnviedField(varName: 'GOOGLE_CLIENT_ID')
  static const String googleClientId = _EnvProd.googleClientId;

  @EnviedField(varName: 'SOCKET_URL')
  static const String socketUrl = _EnvProd.socketUrl;
}
