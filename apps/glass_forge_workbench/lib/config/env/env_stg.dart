import 'package:envied/envied.dart';

part 'env_stg.g.dart';

@Envied(path: 'env/.env.staging')
abstract class EnvStg {
  @EnviedField(varName: 'BASE_URL')
  static const String baseUrl = _EnvStg.baseUrl;

  @EnviedField(varName: 'API_VERSION')
  static const String apiVersion = _EnvStg.apiVersion;

  @EnviedField(varName: 'MAPBOX_API_KEY', obfuscate: true)
  static final String mapboxApiKey = _EnvStg.mapboxApiKey;

  @EnviedField(varName: 'STRIPE_PUBLISHABLE_KEY', obfuscate: true)
  static final String stripePublishableKey = _EnvStg.stripePublishableKey;

  @EnviedField(varName: 'GOOGLE_CLIENT_ID')
  static const String googleClientId = _EnvStg.googleClientId;

  @EnviedField(varName: 'SOCKET_URL')
  static const String socketUrl = _EnvStg.socketUrl;
}
