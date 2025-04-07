import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:pub_semver/src/version.dart';

class ReactNativeConfig extends PluginConfig {
  static final ReactNativeConfig i = ReactNativeConfig._i();

  ReactNativeConfig._i();

  factory ReactNativeConfig() => i;

  @override
  String get archManagerProjectID => '';

  @override
  String get pilotRepoProjectID => '';

  @override
  String get pilotRepoReferredBranch => '';

  @override
  PluginEnvironment get pluginEnvironment => PluginEnvironment.dev;

  @override
  Version get version => Version.parse("1.0.0");
}
