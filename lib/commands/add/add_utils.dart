import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:react_native/config/plugin_config.dart';
import '../../model/specification.dart';
import '../../utils/cli_spinner.dart';
import '../../utils/download_manager.dart';
class ReactNativeUtils extends Command {
  ReactNativeUtils(super.args);

  @override
  String get description => "Manage utilities for React Native project.";
  DownloadManager downloadManager = DownloadManager();

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
    Menu featureMenu = Menu(utilsBranches);
    int idx = featureMenu.choose().index;

    String selectedUtility = 'utils/${utilsBranches[idx]}';

    await _handleUtilityAndSpecification(selectedUtility);
  }

  Future<void> _handleUtilityAndSpecification(String utilityName) async {
    SimpleSpinner spinner = SimpleSpinner();

    spinner.start("Adding $utilityName to the project");

    CWLogger.namedLog("message check whether one time call or not");

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

        List<dynamic> utilityFilePaths = specificationData['filePath'] ?? [];
        List<dynamic> utilityFolderPaths = specificationData['folderPath'] ?? [];

        if (utilityFilePaths.isNotEmpty) {
          for (String utilityFilePath in utilityFilePaths) {
            await downloadManager.downloadFile(utilityFilePath, utilityName);
          }
        }

        if (utilityFolderPaths.isNotEmpty) {
          for (String utilityFolderPath in utilityFolderPaths) {
            await downloadManager.downloadDirectory(utilityFolderPath, utilityName);
          }
        }

        await SpecificationUpdater.updateSpecifications(utilityName);

        spinner.stop(isSuccess: true);
      } else {
        CWLogger.i.trace('Failed to fetch specification_config.json');
        spinner.stop(isSuccess: false);
      }
    } catch (e) {
      spinner.stop(isSuccess: false);
      CWLogger.i.trace(
          'Error downloading utility $utilityName or updating specifications: $e');
    }
  }
}
