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

    argsProcessor
      ..process(
        index: 1,
        processedName: apxInitializationType,
        valid: [
          'standard',
          'custom',
        ],
      )
      ..process(
        index: 2,
        processedName: apxConfigFilePath,
      );

    int? idx = argsProcessor.check(apxInitializationType);

    // If initialization type is not provided, default to "standard"
    if (idx == null) {
      CWLogger.i.stdout("Select init type:");
      Menu menu = Menu([
        'Use standard predefined architectures',
        'Use custom configuration file',
      ]);
      idx = menu.choose().index;
    }

    if (idx == 0) {
      // Fetch list of branches from the GitLab repository
      List<String>? branches = await GitService.getGitLabBranches(
        ReactNativeConfig.i.archManagerProjectID,
        TokenService().accessToken!,
      );

      if (branches == null) {
        CWLogger.namedLog(
          "Error occurred while looking for available architectures",
          loggerColor: CWLoggerColor.red,
        );
        exit(1);
      }

      CWLogger.i.stdout("Select architecture:");
      Menu menu = Menu(branches);
      int branchIdx = menu.choose().index;

      // Start the loading spinner
      CliSpin loader = CliSpin(
          text: "Adapting architecture ${branches[branchIdx]} in the project")
          .start();

      // Download architecture files directly (no need for `__arch_specs.yaml`)
      await GitService.downloadDirectoryContents(
        projectId: ReactNativeConfig.i.archManagerProjectID,
        branch: branches[branchIdx],
        directoryPath: 'components', // Example folder you want to download
        downloadPathBase: RuntimeConfig().commandExecutionPath,
        accessToken: TokenService().accessToken!,
        isProd: ReactNativeConfig.i.pluginEnvironment == PluginEnvironment.prod,
      );

      // Perform the `package.json` merge for React Native
      await PackageJsonUtils.mergeRemotePackageJson(
          ReactNativeConfig.i.archManagerProjectID,
          branches[branchIdx]
      );

      loader.success("Project now follows the selected architecture");

      return;
    }

    String? filePath = argsProcessor.check(ReactNativeInit.apxConfigFilePath);

    if (filePath == null) {
      CWLogger.inLinePrint("Enter the path to config file");
      filePath = stdin.readLineSync();
    }

    // For custom architectures
    CWLogger.i.progress("Migrating the project based on custom Architecture..");
    await ArchTree.createStructureFromJson(
      File(filePath!).readAsStringSync(),
      '.',
    );

    CWLogger.namedLog(
      "Completed Successfully!!",
    );
  }
}
