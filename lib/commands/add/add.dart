import 'dart:io';

import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:react_native/commands/add/add_features.dart';
import 'package:react_native/commands/add/add_utils.dart';

class ReactNativeAdd extends Command {
  ReactNativeAdd(super.args);

  @override
  String get description =>
      "Add features, libraries, or utilities from our main repo.";

  @override
  Future<void> run() async {
    CWLogger.i.stdout('Please select :');
    Menu menu = Menu([
      'Add a Utility',
      'Add a Feature',
    ]);

    int idx = menu.choose().index;

    switch (idx) {
      case 0:
        await ReactNativeUtils(args).run();
      case 1:
        await ReactNativeFeature(args).run();
      default:
        exit(2);
    }
  }
}
