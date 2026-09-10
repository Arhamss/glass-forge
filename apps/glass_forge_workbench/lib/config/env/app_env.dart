import 'package:glass_forge_workbench/config/env/env_dev.dart';
import 'package:glass_forge_workbench/config/env/env_prod.dart';
import 'package:glass_forge_workbench/config/env/env_stg.dart';
import 'package:glass_forge_workbench/config/flavor_config.dart';

class AppEnv {
  AppEnv._();

  static String get baseUrl => switch (FlavorConfig.currentFlavor) {
    Flavor.development => EnvDev.baseUrl,
    Flavor.staging => EnvStg.baseUrl,
    Flavor.production => EnvProd.baseUrl,
  };

  static String get apiVersion => switch (FlavorConfig.currentFlavor) {
    Flavor.development => EnvDev.apiVersion,
    Flavor.staging => EnvStg.apiVersion,
    Flavor.production => EnvProd.apiVersion,
  };

  static String get mapboxApiKey => switch (FlavorConfig.currentFlavor) {
    Flavor.development => EnvDev.mapboxApiKey,
    Flavor.staging => EnvStg.mapboxApiKey,
    Flavor.production => EnvProd.mapboxApiKey,
  };

  static String get stripePublishableKey => switch (FlavorConfig.currentFlavor) {
    Flavor.development => EnvDev.stripePublishableKey,
    Flavor.staging => EnvStg.stripePublishableKey,
    Flavor.production => EnvProd.stripePublishableKey,
  };

  static String get googleClientId => switch (FlavorConfig.currentFlavor) {
    Flavor.development => EnvDev.googleClientId,
    Flavor.staging => EnvStg.googleClientId,
    Flavor.production => EnvProd.googleClientId,
  };

  static String get socketUrl => switch (FlavorConfig.currentFlavor) {
    Flavor.development => EnvDev.socketUrl,
    Flavor.staging => EnvStg.socketUrl,
    Flavor.production => EnvProd.socketUrl,
  };
}
