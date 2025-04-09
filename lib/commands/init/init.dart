import 'dart:io';
import 'package:cli_spin/cli_spin.dart';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import '../../config/plugin_config.dart';
import '../../config/runtime_config.dart';
import '../../utils/package_json.dart'; // Import the new utils file

class ReactNativeInit extends Command {
  ReactNativeInit(super.args);

  @override
  String get description => "Set up standard or custom project architectures.";

  static String apxInitializationType = 'initialization-type';
  static String apxConfigFilePath = 'config-file-path';

  @override
  Future<void> run() async {
    ArgsProcessor argsProcessor = ArgsProcessor(args);

    // Skip the selection of "init type" and directly set it to "standard"
    int idx = 0; // Standard initialization type by default

    // Skip the selection of architecture branches and default to 'main' branch
    String branch = 'main'; // Set default to main branch

    // Start the process of fetching the branches (but default to 'main' without user input)
    List<String>? branches = await GitService.getGitLabBranches(
      ReactNativeConfig.i.archManagerProjectID,
      TokenService().accessToken!,
    );

    if (branches == null || !branches.contains(branch)) {
      CWLogger.namedLog(
        "Error occurred while looking for available architectures or 'main' branch is missing",
        loggerColor: CWLoggerColor.red,
      );
      exit(1);
    }

    // Start the loading spinner
    CliSpin loader = CliSpin(
        text: "Adapting architecture $branch in the project")
        .start();

    // Download architecture files directly from the 'main' branch
    await GitService.downloadDirectoryContents(
      projectId: ReactNativeConfig.i.archManagerProjectID,
      branch: branch,
      directoryPath: 'components', // Example folder to download, you can adjust it
      downloadPathBase: RuntimeConfig().commandExecutionPath,
      accessToken: TokenService().accessToken!,
      isProd: ReactNativeConfig.i.pluginEnvironment == PluginEnvironment.prod,
    );

    // Perform the `package.json` merge for React Native
    await PackageJsonUtils.mergeRemotePackageJson(
        ReactNativeConfig.i.archManagerProjectID,
        branch
    );

    loader.success("Project now follows the selected architecture");

    return;
  }
}
