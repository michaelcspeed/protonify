import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/generated/window_api.g.dart',
  swiftOut: 'macos/Runner/WindowApi.g.swift',
))
@HostApi()
abstract class WindowApi {
  void startDrag();
  void setMenuBarMode(bool enabled);
  bool getMenuBarMode();
}
