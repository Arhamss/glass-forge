import 'package:device_preview/device_preview.dart';
import 'package:glass_forge_workbench/app/view/app_page.dart';
import 'package:glass_forge_workbench/bootstrap.dart';
import 'package:glass_forge_workbench/config/flavor_config.dart';

Future<void> main() async {
  FlavorConfig(flavor: Flavor.development);
  await bootstrap(
    () => DevicePreview(
      enabled: false,
      builder: (context) {
        return const App();
      },
    ),
  );
}
