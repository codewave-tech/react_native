import 'dart:convert';
import 'dart:io';

import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:react_native/config/plugin_config.dart';

import '../../config/runtime_config.dart';

class SpecificationUpdater {
  static Future<void> updateSpecifications(String utilityName) async {
    CWLogger.i.trace("Fetching specifications for $utilityName...");

    // Define the path to fetch the specification_config.json for the utility
    String filePath = '$utilityName/specification_config.json'; // The path to specification_config.json in the branch

    // Fetch the specification_config.json from GitLab
    String? specsFileContent = await GitService.getGitLabFileContent(
      projectId: ReactNativeConfig.i.pilotRepoProjectID,
      filePath: filePath,
      branch: ReactNativeConfig.i.pilotRepoReferredBranch,
      token: TokenService().accessToken!,
    );

    if (specsFileContent != null) {
      // Parse the specification config
      Map<String, dynamic> specificationData = json.decode(specsFileContent);

      // Step 1: Download the utility files
      await _downloadUtilityFiles(utilityName);

      // Step 2: Update package.json with dependencies
      await _updatePackageJson(specificationData['packageJsonDependencies']);

      // Step 3: Update app.json with iOS and Android configurations
      await _updateAppJsonIos(specificationData['appJsonIos']);
      await _updateAppJsonAndroid(specificationData['appJsonAndroid']);

      // Step 4: Update plugins array in app.json
      await _updatePlugins(specificationData['plugins']);
    } else {
      CWLogger.i.trace('Failed to fetch specification_config.json');
    }
  }

  // Method to download the utility files from the repository
  static Future<void> _downloadUtilityFiles(String utilityName) async {
    CWLogger.i.trace("Downloading utility files for $utilityName");

    try {
      await GitService.downloadDirectoryContents(
        projectId: ReactNativeConfig.i.pilotRepoProjectID,
        branch: ReactNativeConfig.i.pilotRepoReferredBranch,
        directoryPath: utilityName,
        downloadPathBase: RuntimeConfig().commandExecutionPath,
        accessToken: TokenService().accessToken!,
      );
      CWLogger.i.trace('Utility files downloaded for $utilityName');
    } catch (e) {
      CWLogger.i.trace('Error downloading utility files: $e');
    }
  }

  // Method to update package.json with dependencies
  static Future<void> _updatePackageJson(Map<String, dynamic> dependencies) async {
    String packageJsonPath = '${RuntimeConfig().commandExecutionPath}/package.json';
    File packageJsonFile = File(packageJsonPath);

    if (!packageJsonFile.existsSync()) {
      CWLogger.i.trace('package.json not found!');
      return;
    }

    String packageJsonContent = await packageJsonFile.readAsString();
    Map<String, dynamic> packageJson = json.decode(packageJsonContent);

    dependencies.forEach((dependency, version) {
      if (!packageJson['dependencies'].containsKey(dependency)) {
        packageJson['dependencies'][dependency] = version;
      }
    });

    // Write updated package.json
    await packageJsonFile.writeAsString(json.encode(packageJson), mode: FileMode.write);
    CWLogger.i.trace('Updated package.json with new dependencies.');
  }

  // Method to update app.json for iOS configurations
  static Future<void> _updateAppJsonIos(Map<String, dynamic> iosConfig) async {
    String appJsonPath = '${RuntimeConfig().commandExecutionPath}/app.json';
    File appJsonFile = File(appJsonPath);

    if (!appJsonFile.existsSync()) {
      CWLogger.i.trace('app.json not found!');
      return;
    }

    String appJsonContent = await appJsonFile.readAsString();
    Map<String, dynamic> appJson = json.decode(appJsonContent);

    if (appJson['expo'] == null) {
      appJson['expo'] = {};
    }

    if (appJson['expo']['ios'] == null) {
      appJson['expo']['ios'] = {};
    }

    iosConfig.forEach((key, value) {
      if (!appJson['expo']['ios'].containsKey(key)) {
        appJson['expo']['ios'][key] = value;
      }
    });

    await appJsonFile.writeAsString(json.encode(appJson), mode: FileMode.write);
    CWLogger.i.trace('Updated app.json with iOS configuration.');
  }

  // Method to update app.json for Android configurations
  static Future<void> _updateAppJsonAndroid(Map<String, dynamic> androidConfig) async {
    String appJsonPath = '${RuntimeConfig().commandExecutionPath}/app.json';
    File appJsonFile = File(appJsonPath);

    if (!appJsonFile.existsSync()) {
      CWLogger.i.trace('app.json not found!');
      return;
    }

    String appJsonContent = await appJsonFile.readAsString();
    Map<String, dynamic> appJson = json.decode(appJsonContent);

    if (appJson['expo'] == null) {
      appJson['expo'] = {};
    }

    if (appJson['expo']['android'] == null) {
      appJson['expo']['android'] = {};
    }

    androidConfig.forEach((key, value) {
      if (!appJson['expo']['android'].containsKey(key)) {
        appJson['expo']['android'][key] = value;
      }
    });

    await appJsonFile.writeAsString(json.encode(appJson), mode: FileMode.write);
    CWLogger.i.trace('Updated app.json with Android configuration.');
  }

  // Method to update plugins array in app.json
  static Future<void> _updatePlugins(List<dynamic> plugins) async {
    String appJsonPath = '${RuntimeConfig().commandExecutionPath}/app.json';
    File appJsonFile = File(appJsonPath);

    if (!appJsonFile.existsSync()) {
      CWLogger.i.trace('app.json not found!');
      return;
    }

    String appJsonContent = await appJsonFile.readAsString();
    Map<String, dynamic> appJson = json.decode(appJsonContent);

    if (appJson['expo'] == null) {
      appJson['expo'] = {};
    }

    if (appJson['expo']['plugins'] == null) {
      appJson['expo']['plugins'] = [];
    }

    for (var plugin in plugins) {
      bool pluginExists = appJson['expo']['plugins']
          .any((existingPlugin) => existingPlugin[0] == plugin[0]);

      if (!pluginExists) {
        appJson['expo']['plugins'].add(plugin);
      }
    }

    await appJsonFile.writeAsString(json.encode(appJson), mode: FileMode.write);
    CWLogger.i.trace('Updated app.json with plugins configuration.');
  }
}
