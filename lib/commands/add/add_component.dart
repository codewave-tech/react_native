import 'dart:convert';
import 'dart:io';

import 'package:cli_spin/cli_spin.dart';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:react_native/config/plugin_config.dart';

import '../../config/runtime_config.dart';
import '../../model/specification.dart';

class ReactNativeComponent extends Command {
  ReactNativeComponent(super.args);

  @override
  String get description => "Manage Components for React Native project.";

  @override
  Future<void> run() async {
    CWLogger.i.progress("Looking for available Components");

    List<String>? dirs = await GitService.getGitLabBranches(
      ReactNativeConfig.i.archManagerProjectID,
      TokenService().accessToken!,
    );

    if (dirs == null || dirs.isEmpty) {
      CWLogger.namedLog(
        'No Components found!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }
    List<String> utilsBranches = dirs
        .where((branch) => branch.startsWith('components/'))
        .map((branch) => branch.replaceFirst('components/', ''))
        .toList();

    if (utilsBranches.isEmpty) {
      CWLogger.namedLog(
        'No Components found in the "components/" directory!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }

    CWLogger.i.stdout("Please select the Component you want to use :");
    Menu featureMenu = Menu(utilsBranches);
    int idx = featureMenu.choose().index;

    String selectedComponent = 'components/${utilsBranches[idx]}';

    await _handleComponentAndSpecification(selectedComponent);
  }

  Future<void> _handleComponentAndSpecification(String componentName) async {
    CliSpin featureLoader =
    CliSpin(text: "Adding $componentName to the project").start();

    try {
      String filePath = 'specification_config.json';
      String? specsFileContent = await GitService.getGitLabFileContent(
        projectId: ReactNativeConfig.i.pilotRepoProjectID,
        filePath: filePath,
        branch: componentName,
        token: TokenService().accessToken!,
      );

      if (specsFileContent != null) {
        Map<String, dynamic> specificationData = json.decode(specsFileContent);

        // Get the filePath and folderPath from the config (with null checks)
        List<dynamic> componentFilePaths = specificationData['filePath'] ?? [];
        List<dynamic> componentFolderPaths = specificationData['folderPath'] ?? [];

        // Handle file paths if available
        if (componentFilePaths.isNotEmpty) {
          for (String componentFilePath in componentFilePaths) {
            await _downloadFile(componentFilePath, componentName);
          }
        }

        // Handle folder paths if available
        if (componentFolderPaths.isNotEmpty) {
          for (String componentFolderPath in componentFolderPaths) {
            await _downloadDirectory(componentFolderPath, componentName);
          }
        }

        await SpecificationUpdater.updateSpecifications(componentName);

        featureLoader.success();
      } else {
        CWLogger.i.trace('Failed to fetch specification_config.json');
      }
    } catch (e) {
      featureLoader.fail();
      CWLogger.namedLog(
        e.toString(),
        loggerColor: CWLoggerColor.red,
      );
      CWLogger.i.trace(
          'Error downloading component $componentName or updating specifications: $e');
    }
  }

  // Method to download individual file
  Future<void> _downloadFile(String componentFilePath, String componentName) async {
    String? fileContent = await GitService.getGitLabFileContent(
      projectId: ReactNativeConfig.i.pilotRepoProjectID,
      filePath: componentFilePath,
      branch: componentName,
      token: TokenService().accessToken!,
    );

    if (fileContent != null) {
      String localFilePath =
          '${RuntimeConfig().commandExecutionPath}/$componentFilePath';
      File localFile = File(localFilePath);

      if (localFile.existsSync()) {
        CWLogger.i.trace('$componentFilePath already exists, skipping download.');
      } else {
        await localFile.create(recursive: true);
        await localFile.writeAsString(fileContent);
        CWLogger.i.trace('Downloaded $componentFilePath successfully.');
      }
    } else {
      CWLogger.i.trace('Failed to fetch $componentFilePath.');
    }
  }

  // Method to download a directory
  Future<void> _downloadDirectory(String componentFolderPath, String componentName) async {
    try {
      await GitService.downloadDirectoryContents(
        projectId: ReactNativeConfig.i.pilotRepoProjectID,
        branch: componentName,
        directoryPath: componentFolderPath,
        downloadPathBase: RuntimeConfig().commandExecutionPath,
        accessToken: TokenService().accessToken!,
      );
      CWLogger.i.trace('Downloaded directory $componentFolderPath successfully.');
    } catch (e) {
      CWLogger.i.trace('Failed to download directory $componentFolderPath: $e');
    }
  }
}
