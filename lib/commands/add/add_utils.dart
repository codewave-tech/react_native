import 'dart:io';

import 'package:cli_spin/cli_spin.dart';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:react_native/config/plugin_config.dart';
import '../../config/runtime_config.dart';
import '../../model/specification.dart'; // Import the SpecificationUpdater

class ReactNativeUtils extends Command {
  ReactNativeUtils(super.args);

  @override
  String get description => "Manage utilities for React Native project.";

  @override
  Future<void> run() async {
    CWLogger.i.progress("Looking for available Utilities");

    List<String>? dirs = await GitService.getGitLabBranches(
      ReactNativeConfig.i.pilotRepoProjectID,
      TokenService().accessToken!,
    );

    if (dirs == null || dirs.isEmpty) {
      CWLogger.namedLog(
        'No utilities found!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }

    // Filter out utils branches (utils/permissionUtils, utils/validations, etc.)
    List<String> utilsBranches = dirs
        .where((branch) => branch.startsWith('utils/'))
        .map((branch) => branch.replaceFirst('utils/', '')) // Remove 'utils/' prefix
        .toList();

    if (utilsBranches.isEmpty) {
      CWLogger.namedLog(
        'No utilities found in the "utils/" directory!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }

    CWLogger.i.stdout("Please select the Utility you want to use :");
    Menu featureMenu = Menu(utilsBranches);
    int idx = featureMenu.choose().index;

    // Get the full branch name (e.g., 'utils/permissionUtils')
    String selectedUtility = 'utils/${utilsBranches[idx]}';

    // Add the selected utility to the project and update configurations
    await _handleUtilityAndSpecification(selectedUtility);
  }

  // Combined method to download utility files and update project configurations
  Future<void> _handleUtilityAndSpecification(String utilityName) async {
    CliSpin featureLoader = CliSpin(text: "Adding $utilityName to the project").start();

    try {
      // Download the utility files from the GitLab repository

      String filePath = '$utilityName/utils/PermissionUtil.ts'; // The path to the utility file
      String? fileContent = await GitService.getGitLabFileContent(
        projectId: ReactNativeConfig.i.pilotRepoProjectID,
        filePath: filePath,
        branch: ReactNativeConfig.i.pilotRepoReferredBranch,
        token: TokenService().accessToken!,
      );

      if (fileContent != null) {
        // Define the path where we want to store the file locally
        String localPath = '${RuntimeConfig()
            .commandExecutionPath}/utils/PermissionUtil.ts';
        File localFile = File(localPath);

        if (localFile.existsSync()) {
          CWLogger.i.trace(
              'PermissionUtil.ts already exists, skipping download.');
          return;
        }

        await localFile.create(recursive: true);
        await localFile.writeAsString(fileContent);
      }
      await SpecificationUpdater.updateSpecifications(utilityName);
      featureLoader.success();


      CWLogger.i.trace("Utility $utilityName has been successfully added and updated.");
    } catch (e) {
      featureLoader.fail();
      CWLogger.i.trace('Error downloading utility $utilityName or updating specifications: $e');
    }
  }
}
