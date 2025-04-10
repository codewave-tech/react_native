import 'dart:convert';
import 'dart:io';

import 'package:cli_spin/cli_spin.dart';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:react_native/config/plugin_config.dart';

import '../../config/runtime_config.dart';
import '../../model/specification.dart';

class ReactNativeUtils extends Command {
  ReactNativeUtils(super.args);

  @override
  String get description => "Manage utilities for React Native project.";

  @override
  Future<void> run() async {
    CWLogger.i.progress("Looking for available Utilities");

    List<String>? dirs = await GitService.getGitLabBranches(
      ReactNativeConfig.i.archManagerProjectID,
      TokenService().accessToken!,
    );

    if (dirs == null || dirs.isEmpty) {
      CWLogger.namedLog(
        'No utilities found!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }
    CWLogger.i.stdout(dirs.toSet().toString());
    List<String> utilsBranches = dirs
        .where((branch) => branch.startsWith('utils/'))
        .map((branch) => branch.replaceFirst('utils/', ''))
        .toList();

    if (utilsBranches.isEmpty) {
      CWLogger.namedLog(
        'No utilities found in the "utils/" directory!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }

    CWLogger.i.stdout("Please select the Utility you want to use :");
    CWLogger.i.stdout(utilsBranches.toString());
    Menu featureMenu = Menu(utilsBranches);
    int idx = featureMenu.choose().index;

    String selectedUtility = 'utils/${utilsBranches[idx]}';

    await _handleUtilityAndSpecification(selectedUtility);
  }

  Future<void> _handleUtilityAndSpecification(String utilityName) async {
    CliSpin featureLoader =
        CliSpin(text: "Adding $utilityName to the project").start();

    try {
      String filePath = 'specification_config.json';
      String? specsFileContent = await GitService.getGitLabFileContent(
        projectId: ReactNativeConfig.i.pilotRepoProjectID,
        filePath: filePath,
        branch: utilityName,
        token: TokenService().accessToken!,
      );

      if (specsFileContent != null) {
        Map<String, dynamic> specificationData = json.decode(specsFileContent);

        List<dynamic> utilityFilePaths = specificationData['filePath'];

        for (String utilityFilePath in utilityFilePaths) {
          String? fileContent = await GitService.getGitLabFileContent(
            projectId: ReactNativeConfig.i.pilotRepoProjectID,
            filePath: utilityFilePath,
            branch: utilityName,
            token: TokenService().accessToken!,
          );

          if (fileContent != null) {
            String localFilePath =
                '${RuntimeConfig().commandExecutionPath}/$utilityFilePath';
            File localFile = File(localFilePath);

            if (localFile.existsSync()) {
              CWLogger.i
                  .trace('$utilityFilePath already exists, skipping download.');
            } else {
              await localFile.create(recursive: true);
              await localFile.writeAsString(fileContent);
              CWLogger.i.trace('Downloaded $utilityFilePath successfully.');
            }
          } else {
            CWLogger.i.trace('Failed to fetch $utilityFilePath.');
          }
        }

        await SpecificationUpdater.updateSpecifications(utilityName);

        featureLoader.success();
      } else {
        CWLogger.i.trace('Failed to fetch specification_config.json');
      }
    } catch (e) {
      featureLoader.fail();
      CWLogger.i.trace(
          'Error downloading utility $utilityName or updating specifications: $e');
    }
  }
}
