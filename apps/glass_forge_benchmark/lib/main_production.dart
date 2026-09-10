import 'package:glass_forge_benchmark/app/view/app_page.dart';
import 'package:glass_forge_benchmark/bootstrap.dart';
import 'package:glass_forge_benchmark/config/flavor_config.dart';

Future<void> main() async {
  FlavorConfig(flavor: Flavor.production);
  await bootstrap(App.new);
}
