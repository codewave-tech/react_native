import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:react_native/commands/add/add.dart';

import 'commands/init/init.dart';
import 'config/runtime_config.dart';

class ReactNative extends Plugin {
  ReactNative(super.args);

  @override
  String get pluginName => 'react_native';

  @override
  Version get version => Version.parse("1.1.1");

  @override
  String get alias => 'rn';

  @override
  Map<String, Command> get commands => {
    "init": ReactNativeInit(args),
    "add": ReactNativeAdd(args),
  };

  @override
  void pluginEntry() async{
    super.pluginEntry();
    await RuntimeConfig().initialize();
    if (commands.containsKey(args[0])) {
      commands[args[0]]?.run();
    }
  }
}

