import 'dart:convert';
import 'dart:io';

import 'package:cli_spin/cli_spin.dart';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:react_native/config/plugin_config.dart';

import '../../config/runtime_config.dart';
import '../../model/specification.dart';

class ReactNativeFeature extends Command {
  ReactNativeFeature(super.args);

  @override
  String get description => "";

  @override
  Future<void> run() async {
    CWLogger.i.progress("Looking for available Features");

    List<String>? dirs = await GitService.getGitLabBranches(
      ReactNativeConfig.i.archManagerProjectID,
      TokenService().accessToken!,
    );

    if (dirs == null || dirs.isEmpty) {
      CWLogger.namedLog(
        'No Features found!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }
    CWLogger.i.stdout(dirs.toSet().toString());
    List<String> featureBranches = dirs
        .where((branch) => branch.startsWith('features/'))
        .map((branch) => branch.replaceFirst('features/', ''))
        .toList();

    if (featureBranches.isEmpty) {
      CWLogger.namedLog(
        'No Features found in the "features/" directory!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }

    CWLogger.i.stdout("Please select the Feature you want to use :");
    CWLogger.i.stdout(featureBranches.toString());
    Menu featureMenu = Menu(featureBranches);
    int idx = featureMenu.choose().index;

    String selectedFeature = 'features/${featureBranches[idx]}';

    await _handleFeatureAndSpecification(selectedFeature);
  }

  Future<void> _handleFeatureAndSpecification(String featureName) async {
    CliSpin featureLoader =
    CliSpin(text: "Adding $featureName to the project").start();

    try {
      String filePath = 'specification_config.json';
      String? specsFileContent = await GitService.getGitLabFileContent(
        projectId: ReactNativeConfig.i.pilotRepoProjectID,
        filePath: filePath,
        branch: featureName,
        token: TokenService().accessToken!,
      );

      if (specsFileContent != null) {
        Map<String, dynamic> specificationData = json.decode(specsFileContent);

        // Get the filePath and folderPath from the config
        List<dynamic> featuresFilePaths = specificationData['filePath'] ?? [];
        List<dynamic> featuresFolderPaths = specificationData['folderPath'] ?? [];

        // Handle file paths if available
        if (featuresFilePaths.isNotEmpty) {
          for (String featureFilePath in featuresFilePaths) {
            await _downloadFile(featureFilePath, featureName);
          }
        }

        // Handle folder paths if available
        if (featuresFolderPaths.isNotEmpty) {
          for (String featureFolderPath in featuresFolderPaths) {
            await _downloadDirectory(featureFolderPath, featureName);
          }
        }

        await SpecificationUpdater.updateSpecifications(featureName);

        featureLoader.success();
      } else {
        CWLogger.i.trace('Failed to fetch specification_config.json');
      }
    } catch (e) {
      featureLoader.fail();
      CWLogger.i.trace(
          'Error downloading Feature $featureName or updating specifications: $e');
    }
  }

  // Method to download individual file
  Future<void> _downloadFile(String featureFilePath, String featureName) async {
    String? fileContent = await GitService.getGitLabFileContent(
      projectId: ReactNativeConfig.i.pilotRepoProjectID,
      filePath: featureFilePath,
      branch: featureName,
      token: TokenService().accessToken!,
    );

    if (fileContent != null) {
      String localFilePath =
          '${RuntimeConfig().commandExecutionPath}/$featureFilePath';
      File localFile = File(localFilePath);

      if (localFile.existsSync()) {
        CWLogger.i.trace('$featureFilePath already exists, skipping download.');
      } else {
        await localFile.create(recursive: true);
        await localFile.writeAsString(fileContent);
        CWLogger.i.trace('Downloaded $featureFilePath successfully.');
      }
    } else {
      CWLogger.i.trace('Failed to fetch $featureFilePath.');
    }
  }

  // Method to download a directory
  Future<void> _downloadDirectory(String featureFilePath, String featureName) async {
    try {
      await GitService.downloadDirectoryContents(
        projectId: ReactNativeConfig.i.pilotRepoProjectID,
        branch: featureName,
        directoryPath: featureFilePath,
        downloadPathBase: RuntimeConfig().commandExecutionPath,
        accessToken: TokenService().accessToken!,
      );
      CWLogger.i.trace('Downloaded directory $featureFilePath successfully.');
    } catch (e) {
      CWLogger.i.trace('Failed to download directory $featureFilePath: $e');
    }
  }
}
