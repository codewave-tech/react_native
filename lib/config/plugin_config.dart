import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:pub_semver/src/version.dart';

class ReactNativeConfig extends PluginConfig {
  static final ReactNativeConfig i = ReactNativeConfig._i();

  ReactNativeConfig._i();

  factory ReactNativeConfig() => i;

  @override
  String get archManagerProjectID => '68118890';

  @override
  String get pilotRepoProjectID => '68118890';

  @override
  String get pilotRepoReferredBranch => '';

  @override
  PluginEnvironment get pluginEnvironment => PluginEnvironment.prod;

  @override
  Version get version => Version.parse("1.5.0");
}
