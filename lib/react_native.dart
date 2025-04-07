import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:pub_semver/pub_semver.dart';

class ReactNative extends Plugin {
  ReactNative(super.args);

  @override
  String get pluginName => 'react_native';

  @override
  Version get version => Version.parse("1.0.0");

  @override
  String get alias => 'rn';

  @override
  Map<String, Command> get commands => {};

  @override
  void pluginEntry() {
    super.pluginEntry();

    if (commands.containsKey(args[0])) {
      commands[args[0]]?.run();
    }
  }
}

