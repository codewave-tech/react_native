import 'dart:io';

import 'package:cwa_plugin_core/cwa_plugin_core.dart';

import 'package:pubspec/pubspec.dart';

import 'plugin_config.dart';

class RuntimeConfig extends RTC<PubSpec> {
  static final RuntimeConfig _runtimeConfig = RuntimeConfig._i();

  RuntimeConfig._i();

  factory RuntimeConfig() => _runtimeConfig;

  static final String l10nPath = 'lib/core/l10n';
  static final String l10ngeneratedPath = 'lib/core/l10n/generated';
  static final String l10nAppStringPath = 'lib/core/l10n/app_strings.dart';
  static final String libraryPath = 'lib/libraries';
  static final String featureLocation = 'lib/features';

  @override
  Future<void> initialize() async {
    switch (ReactNativeConfig.i.pluginEnvironment) {
      case PluginEnvironment.dev:
        commandExecutionPath = '';
        break;
      case PluginEnvironment.prod:
        commandExecutionPath = Directory.current.path;
        break;
    }

    // intialize your dependency manager here
    // dependencyManager =
  }

  @override
  void displayStartupBanner() {
    // stuff to show on startup
  }
}
