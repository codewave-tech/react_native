import 'dart:convert';
import 'dart:io';

import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:react_native/config/plugin_config.dart';

import '../../config/runtime_config.dart';
import '../utils/package_json.dart';

class SpecificationUpdater {
  static Future<void> updateSpecifications(String utilityName) async {
    CWLogger.namedLog("Fetching specifications for $utilityName...");

    String filePath = 'specification_config.json';

    String? specsFileContent = await GitService.getGitLabFileContent(
      projectId: ReactNativeConfig.i.pilotRepoProjectID,
      filePath: filePath,
      branch: utilityName,
      token: TokenService().accessToken!,
    );

    if (specsFileContent != null) {
      Map<String, dynamic> specificationData = json.decode(specsFileContent);
      CWLogger.namedLog("Specification config loaded successfully.");
      await _updatePackageJson(
          specificationData['packageJsonDependencies'], specificationData);
      await _updateAppJsonIos(specificationData['appJsonIos']);
      await _updateAppJsonAndroid(specificationData['appJsonAndroid']);
      await _updatePlugins(specificationData['plugins']);
      await _updateAppWrapper(specificationData['jsxModifications']);
      await PackageJsonUtils.runYarnInstall();
    } else {
      CWLogger.namedLog('Failed to fetch specification_config.json');
    }
  }

  static Future<void> _updatePackageJson(Map<String, dynamic> dependencies,
      Map<String, dynamic> specificationData) async {
    String packageJsonPath =
        '${RuntimeConfig().commandExecutionPath}/package.json';
    File packageJsonFile = File(packageJsonPath);
    if (!packageJsonFile.existsSync()) {
      CWLogger.namedLog('package.json not found!');
      return;
    }
    String packageJsonContent = await packageJsonFile.readAsString();
    Map<String, dynamic> packageJson = json.decode(packageJsonContent);
    dependencies.forEach((dependency, version) {
      if (!packageJson['dependencies'].containsKey(dependency)) {
        packageJson['dependencies'][dependency] = version;
        CWLogger.namedLog('Added $dependency to package.json');
      } else {
        CWLogger.namedLog('$dependency already exists in package.json');
      }
    });

    if (specificationData.containsKey('expo')) {
      Map<String, dynamic> expoConfig = specificationData['expo'];

      if (expoConfig.containsKey('doctor')) {
        Map<String, dynamic> doctorConfig = expoConfig['doctor'];

        if (doctorConfig.containsKey('reactNativeDirectoryCheck') &&
            doctorConfig['reactNativeDirectoryCheck'] is Map<String, dynamic>) {
          Map<String, dynamic> reactNativeDirectoryCheckConfig =
              doctorConfig['reactNativeDirectoryCheck'];

          if (!packageJson.containsKey('expo')) {
            packageJson['expo'] = {};
          }
          if (!packageJson['expo'].containsKey('doctor')) {
            packageJson['expo']['doctor'] = {};
          }
          if (!packageJson['expo']['doctor']
              .containsKey('reactNativeDirectoryCheck')) {
            packageJson['expo']['doctor']['reactNativeDirectoryCheck'] = {};
            CWLogger.namedLog(
                'Created missing reactNativeDirectoryCheck in package.json (expo.doctor).');
          }

          if (reactNativeDirectoryCheckConfig.containsKey('exclude')) {
            List<dynamic> excludeList =
                reactNativeDirectoryCheckConfig['exclude'];
            List<dynamic> existingExcludeList = packageJson['expo']['doctor']
                    ['reactNativeDirectoryCheck']['exclude'] ??
                [];

            for (var excludeItem in excludeList) {
              if (!existingExcludeList.contains(excludeItem)) {
                existingExcludeList.add(excludeItem);
                CWLogger.namedLog(
                    'Added $excludeItem to reactNativeDirectoryCheck.exclude in package.json (expo.doctor).');
              } else {
                CWLogger.namedLog(
                    '$excludeItem already exists in reactNativeDirectoryCheck.exclude.');
              }
            }

            packageJson['expo']['doctor']['reactNativeDirectoryCheck']
                ['exclude'] = existingExcludeList;
          }

          if (reactNativeDirectoryCheckConfig
              .containsKey('listUnknownPackages')) {
            packageJson['expo']['doctor']['reactNativeDirectoryCheck']
                    ['listUnknownPackages'] =
                reactNativeDirectoryCheckConfig['listUnknownPackages'];
            CWLogger.namedLog(
                'Updated listUnknownPackages in reactNativeDirectoryCheck in package.json (expo.doctor).');
          }
        }
      }
    }

    await packageJsonFile.writeAsString(json.encode(packageJson),
        mode: FileMode.write);
    CWLogger.namedLog('Updated package.json with new dependencies.');
  }

  static Future<void> _updateAppJsonIos(Map<String, dynamic> iosConfig) async {
    String appJsonPath = '${RuntimeConfig().commandExecutionPath}/app.json';
    File appJsonFile = File(appJsonPath);

    if (!appJsonFile.existsSync()) {
      CWLogger.namedLog('app.json not found!');
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

    if (iosConfig != null) {
      iosConfig.forEach((key, value) {
        if (key == 'infoPlist') {
          if (appJson['expo']['ios']['infoPlist'] == null) {
            appJson['expo']['ios']['infoPlist'] = {};
            CWLogger.namedLog('Created missing infoPlist in app.json (iOS).');
          }

          value.forEach((plistKey, plistValue) {
            if (!appJson['expo']['ios']['infoPlist'].containsKey(plistKey)) {
              appJson['expo']['ios']['infoPlist'][plistKey] = plistValue;
              CWLogger.namedLog(
                  'Added $plistKey to infoPlist in app.json (iOS).');
              CWLogger.namedLog(
                  'Added $plistValue to infoPlist in app.json (iOS).');
            } else {
              CWLogger.namedLog(
                  '$plistKey already exists in infoPlist in app.json (iOS).');
            }
          });
        } else if (key == 'config') {
          if (value != null) {
            if (appJson['expo']['ios']['config'] == null) {
              appJson['expo']['ios']['config'] = {};
              CWLogger.namedLog('Created missing config in app.json (iOS).');
            }

            value.forEach((configKey, configValue) {
              if (appJson['expo']['ios']['config'][configKey] == null ||
                  appJson['expo']['ios']['config'][configKey] != configValue) {
                appJson['expo']['ios']['config'][configKey] = configValue;
                CWLogger.namedLog(
                    'Added/Updated $configKey in config in app.json (iOS) to $configValue.');
              } else {
                CWLogger.namedLog(
                    '$configKey already exists in config in app.json (iOS) with the same value.');
              }
            });
          }
        } else {
          if (appJson['expo']['ios'][key] == null ||
              appJson['expo']['ios'][key] != value) {
            appJson['expo']['ios'][key] = value;
            CWLogger.namedLog(
                'Added/Updated $key in app.json (iOS) to $value.');
          } else {
            CWLogger.namedLog(
                '$key already exists in app.json (iOS) with the same value.');
          }
        }
      });
    }

    await appJsonFile.writeAsString(json.encode(appJson), mode: FileMode.write);
    CWLogger.namedLog('Updated app.json with iOS configurations.');
  }

  static Future<void> _updateAppJsonAndroid(
      Map<String, dynamic> androidConfig) async {
    String appJsonPath = '${RuntimeConfig().commandExecutionPath}/app.json';
    File appJsonFile = File(appJsonPath);

    if (!appJsonFile.existsSync()) {
      CWLogger.namedLog('app.json not found!');
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

    if (appJson['expo']['android']['permissions'] == null) {
      appJson['expo']['android']['permissions'] = [];
      CWLogger.namedLog(
          'Created missing permissions array in app.json (Android).');
    }

    List<dynamic> newPermissions = androidConfig['permissions'] ?? [];
    for (var permission in newPermissions) {
      if (!appJson['expo']['android']['permissions'].contains(permission)) {
        appJson['expo']['android']['permissions'].add(permission);
        CWLogger.namedLog(
            'Added $permission to app.json (Android) permissions.');
      } else {
        CWLogger.namedLog(
            '$permission already exists in app.json (Android) permissions.');
      }
    }

    await appJsonFile.writeAsString(json.encode(appJson), mode: FileMode.write);
    CWLogger.namedLog('Updated app.json with Android configuration.');
  }

  static Future<void> _updatePlugins(List<dynamic> plugins) async {
    String appJsonPath = '${RuntimeConfig().commandExecutionPath}/app.json';
    File appJsonFile = File(appJsonPath);

    if (!appJsonFile.existsSync()) {
      CWLogger.namedLog('app.json not found!');
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
        CWLogger.namedLog('Added $plugin to app.json plugins.');
      } else {
        CWLogger.namedLog('$plugin already exists in app.json plugins.');
      }
    }

    await appJsonFile.writeAsString(json.encode(appJson), mode: FileMode.write);
    CWLogger.namedLog('Updated app.json with plugins configuration.');
  }

  static Future<void> _updateAppWrapper(
      Map<String, dynamic> jsxModifications) async {
    String appWrapperPath =
        '${RuntimeConfig().commandExecutionPath}/components/appWrapper/AppWrapper.tsx';
    File appWrapperFile = File(appWrapperPath);

    if (!appWrapperFile.existsSync()) {
      CWLogger.namedLog('AppWrapper.tsx not found!');
      return;
    }

    String appWrapperContent = await appWrapperFile.readAsString();



    if (jsxModifications.containsKey('jsxChanges')) {
      List<dynamic> jsxChanges = jsxModifications['jsxChanges'];

      for (var changeConfig in jsxChanges) {
        String component = changeConfig['component'];
        String wrapComponent = changeConfig['wrapComponent'];
        String wrapper = changeConfig['wrapper'];

        if (component == "AppWrapper" &&
            wrapComponent == "KeyboardProvider" &&
            !appWrapperContent.contains(wrapper)) {
          appWrapperContent = appWrapperContent.replaceFirst(
              "<$wrapComponent>", "<$wrapper>\n    <$wrapComponent>\n");
          appWrapperContent = appWrapperContent.replaceFirst(
              "</$wrapComponent>", "\n    </$wrapComponent>\n</$wrapper>");
          CWLogger.namedLog(
              'Wrapped $wrapComponent with $wrapper in AppWrapper.tsx.');
        }
      }
    }
    if (jsxModifications.containsKey('imports')) {
      List<dynamic> imports = jsxModifications['imports'];

      for (var importConfig in imports) {
        String importStatement = importConfig['importStatement'];
        if (!appWrapperContent.contains(importStatement)) {
          appWrapperContent = importStatement + '\n' + appWrapperContent;
          CWLogger.namedLog(
              'Added import: $importStatement to AppWrapper.tsx.');
        } else {
          CWLogger.namedLog('Import already exists: $importStatement.');
        }
      }
    }

    await appWrapperFile.writeAsString(appWrapperContent, mode: FileMode.write);
    CWLogger.namedLog('Updated AppWrapper.tsx with dynamic changes.');
  }
}
