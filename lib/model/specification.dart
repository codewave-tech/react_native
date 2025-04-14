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
      await _updateAppWrapper(specificationData['jsxModifications']??{});
      await _updateMetroConfig(specificationData['metroConfigChanges']??{});
      await _updateAppLayout(specificationData['appLayoutChanges']??{});
      await _updateStoreFile(specificationData['storeChanges']??{});
      await PackageJsonUtils.runYarnInstall();
    } else {
      CWLogger.namedLog('Failed to fetch specification_config.json');
    }
  }

  static Future<void> _updatePackageJson(Map<String, dynamic> dependencies,
      Map<String, dynamic> specificationData) async {
    String packageJsonPath = '${RuntimeConfig().commandExecutionPath}/package.json';
    File packageJsonFile = File(packageJsonPath);
    if (!packageJsonFile.existsSync()) {
      CWLogger.namedLog('package.json not found!');
      return;
    }
    String packageJsonContent = await packageJsonFile.readAsString();
    Map<String, dynamic> packageJson = json.decode(packageJsonContent);

    // Handle normal dependencies
    dependencies.forEach((dependency, version) {
      if (!packageJson['dependencies'].containsKey(dependency)) {
        packageJson['dependencies'][dependency] = version;
        CWLogger.namedLog('Added $dependency to package.json');
      } else {
        CWLogger.namedLog('$dependency already exists in package.json');
      }
    });

    // Handle devDependencies
    if (specificationData.containsKey('packageJsonDevDependencies')) {
      Map<String, dynamic> devDependencies = specificationData['packageJsonDevDependencies'];

      // Ensure devDependencies section exists
      if (!packageJson.containsKey('devDependencies')) {
        packageJson['devDependencies'] = {};
      }

      devDependencies.forEach((dependency, version) {
        if (!packageJson['devDependencies'].containsKey(dependency)) {
          packageJson['devDependencies'][dependency] = version;
          CWLogger.namedLog('Added $dependency to devDependencies in package.json');
        } else {
          CWLogger.namedLog('$dependency already exists in devDependencies.');
        }
      });
    }

    // Handle expo.doctor.reactNativeDirectoryCheck (same as existing code)
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

    // Iterate through the plugins to be added
    for (var plugin in plugins) {
      if (plugin is String) {
        // Handle string plugins like "expo-router"
        bool pluginExists = appJson['expo']['plugins'].contains(plugin);

        if (!pluginExists) {
          appJson['expo']['plugins'].add(plugin);
          CWLogger.namedLog('Added string plugin $plugin to app.json plugins.');
        } else {
          CWLogger.namedLog('String plugin $plugin already exists in app.json plugins.');
        }
      } else if (plugin is List) {
        // Handle array-based plugins like ["expo-splash-screen", { ... }]
        bool pluginExists = appJson['expo']['plugins']
            .any((existingPlugin) =>
        existingPlugin is List && existingPlugin[0] == plugin[0]);

        if (!pluginExists) {
          appJson['expo']['plugins'].add(plugin);
          CWLogger.namedLog('Added array plugin ${plugin[0]} to app.json plugins.');
        } else {
          CWLogger.namedLog('Array plugin ${plugin[0]} already exists in app.json plugins.');
        }
      }
    }

    // Write the updated content back to app.json
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

    // Handle JSX changes (wrapping components)
    if (jsxModifications.containsKey('jsxChanges')) {
      List<dynamic> jsxChanges = jsxModifications['jsxChanges'];

      for (var changeConfig in jsxChanges) {
        String component = changeConfig['component'];
        String wrapComponent = changeConfig['wrapComponent'];
        String wrapper = changeConfig['wrapper'];
        Map<String, dynamic>? wrapperProps = changeConfig['wrapperProps'];

        if (component == "AppWrapper" &&
            wrapComponent == "KeyboardProvider" &&
            !appWrapperContent.contains(wrapper)) {

          // Wrap the component with the wrapper
          appWrapperContent = appWrapperContent.replaceFirst(
              "<$wrapComponent>", "<$wrapper>\n    <$wrapComponent>\n");
          appWrapperContent = appWrapperContent.replaceFirst(
              "</$wrapComponent>", "\n    </$wrapComponent>\n</$wrapper>");

          // Optionally handle `wrapperProps`
          if (wrapperProps != null) {
            // Convert the `wrapperProps` map to a string (if needed)
            String wrapperPropsString = _convertWrapperPropsToString(wrapperProps);
            appWrapperContent = appWrapperContent.replaceFirst(
                "<$wrapper>", "<$wrapper $wrapperPropsString>");
            CWLogger.namedLog(
                'Added wrapperProps to $wrapper in AppWrapper.tsx.');
          }

          CWLogger.namedLog('Wrapped $wrapComponent with $wrapper in AppWrapper.tsx.');
        }
      }
    }

    // Handle Imports
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

// Helper method to convert wrapperProps map to string (if necessary)
  static String _convertWrapperPropsToString(Map<String, dynamic> wrapperProps) {
    List<String> props = [];
    wrapperProps.forEach((key, value) {
      props.add('$key="$value"');
    });
    return props.join(' ');
  }

  static Future<void> _updateMetroConfig(Map<String, dynamic> configChanges) async {
    String metroConfigPath =
        '${RuntimeConfig().commandExecutionPath}/metro.config.js';
    File metroConfigFile = File(metroConfigPath);

    if (!metroConfigFile.existsSync()) {
      CWLogger.namedLog('metro.config.js not found!');
      return;
    }

    String metroConfigContent = await metroConfigFile.readAsString();

    // Handle 'assetExts' changes: Add 'lottie' and remove 'svg'
    if (configChanges.containsKey('assetExts')) {
      var assetExtsChanges = configChanges['assetExts'];
      if (assetExtsChanges != null && assetExtsChanges is List) {
        assetExtsChanges.forEach((extChange) {
          // Remove "svg" from assetExts and add "lottie"
          if (!metroConfigContent.contains('assetExts: [...resolver.assetExts.filter((ext) => ext !== "svg"), "$extChange"]')) {
            metroConfigContent = metroConfigContent.replaceFirst(
                "assetExts: resolver.assetExts.filter((ext) => ext !== \"svg\")",
                "assetExts: [...resolver.assetExts.filter((ext) => ext !== \"svg\"), \"$extChange\"]");
            CWLogger.namedLog('Added asset extension: $extChange to metro.config.js.');
          } else {
            CWLogger.namedLog('Asset extension $extChange already exists.');
          }
        });
      }
    }

    // Handle 'sourceExts' changes: Add 'lottie' and 'svg'
    if (configChanges.containsKey('sourceExts')) {
      var sourceExtsChanges = configChanges['sourceExts'];
      if (sourceExtsChanges != null && sourceExtsChanges is List) {
        sourceExtsChanges.forEach((extChange) {
          // Add "lottie" to sourceExts and ensure "svg" is still included
          if (!metroConfigContent.contains('sourceExts: [...resolver.sourceExts, "svg", "$extChange"]')) {
            metroConfigContent = metroConfigContent.replaceFirst(
                "sourceExts: [...resolver.sourceExts]",
                "sourceExts: [...resolver.sourceExts, \"svg\", \"$extChange\"]");
            CWLogger.namedLog('Added source extension: $extChange to metro.config.js.');
          } else {
            CWLogger.namedLog('Source extension $extChange already exists.');
          }
        });
      }
    }

    // Write the updated content back to metro.config.js
    await metroConfigFile.writeAsString(metroConfigContent, mode: FileMode.write);
    CWLogger.namedLog('Updated metro.config.js with new extensions.');
  }

  static Future<void> _updateAppLayout(Map<String, dynamic> appLayoutChanges) async {
    String appLayoutPath = '${RuntimeConfig().commandExecutionPath}/app/_layout.tsx';
    File appLayoutFile = File(appLayoutPath);

    if (!appLayoutFile.existsSync()) {
      CWLogger.namedLog('_layout.tsx not found!');
      return;
    }

    String appLayoutContent = await appLayoutFile.readAsString();

    // Handle imports for Redux and any other dynamic imports
    if (appLayoutChanges.containsKey('imports')) {
      List<dynamic> imports = appLayoutChanges['imports'];

      for (var importConfig in imports) {
        String importStatement = importConfig['importStatement'];
        // Ensure each import is added only once
        if (!appLayoutContent.contains(importStatement)) {
          appLayoutContent = importStatement + '\n' + appLayoutContent;
          CWLogger.namedLog('Added import: $importStatement to _layout.tsx.');
        } else {
          CWLogger.namedLog('Import already exists: $importStatement.');
        }
      }
    }

    // Handle adding the Provider and PersistGate around the return statement dynamically
    if (appLayoutChanges.containsKey('providerPersistGateWrapper') &&
        appLayoutChanges.containsKey('providerPersistGateClose')) {
      String providerPersistGateWrapper = appLayoutChanges['providerPersistGateWrapper'];
      String providerPersistGateClose = appLayoutChanges['providerPersistGateClose'];

      // Find the return statement pattern
      RegExp returnRegExp = RegExp(r'return\s*\(');
      Match? returnMatch = returnRegExp.firstMatch(appLayoutContent);

      if (returnMatch != null) {
        int returnStartIndex = returnMatch.end; // Position after "return ("

        // Now find the matching closing parenthesis
        int openParens = 1; // We start with one open parenthesis from "return ("
        int closeIndex = returnStartIndex;

        // Find the matching closing parenthesis by counting opening and closing parentheses
        for (int i = returnStartIndex; i < appLayoutContent.length; i++) {
          if (appLayoutContent[i] == '(') {
            openParens++;
          } else if (appLayoutContent[i] == ')') {
            openParens--;
            if (openParens == 0) {
              // We found the matching closing parenthesis
              closeIndex = i;
              break;
            }
          }
        }

        // Extract the parts of the content
        String beforeReturn = appLayoutContent.substring(0, returnStartIndex);
        String returnContent = appLayoutContent.substring(returnStartIndex, closeIndex);
        String afterReturn = appLayoutContent.substring(closeIndex);

        // Create the updated content with wrapper components
        appLayoutContent = beforeReturn + providerPersistGateWrapper + returnContent + providerPersistGateClose + afterReturn;

        CWLogger.namedLog('Wrapped return statement with Provider and PersistGate in _layout.tsx.');
      } else {
        CWLogger.namedLog('Could not find return statement pattern in _layout.tsx.');
      }
    }

    // Write the updated content back to _layout.tsx
    await appLayoutFile.writeAsString(appLayoutContent, mode: FileMode.write);
    CWLogger.namedLog('Updated _layout.tsx with imports and wrapping of return statement.');
  }
  static Future<void> _updateStoreFile(Map<String, dynamic> storeChanges) async {
    String storeFilePath = '${RuntimeConfig().commandExecutionPath}/${storeChanges['filePath']}';
    File storeFile = File(storeFilePath);

    if (!storeFile.existsSync()) {
      CWLogger.namedLog('store.ts not found!');
      return;
    }

    String storeContent = await storeFile.readAsString();
    Map<String, dynamic> storeJson = json.decode(storeContent);

    // Ensure the whitelist array exists
    if (!storeJson.containsKey('whitelist')) {
      storeJson['whitelist'] = [];
      CWLogger.namedLog('Created missing whitelist array in store.ts.');
    }

    // Add the RefreshControlSlice to the whitelist if not already present
    List<dynamic> whitelist = storeJson['whitelist'];
    if (!whitelist.contains(storeChanges['whitelistArrayChanges'][0])) {
      whitelist.add(storeChanges['whitelistArrayChanges'][0]);
      CWLogger.namedLog('Added RefreshControlSlice to whitelist in store.ts.');
    } else {
      CWLogger.namedLog('RefreshControlSlice already exists in whitelist in store.ts.');
    }

    // Ensure the reducers object exists
    if (!storeJson.containsKey('reducers')) {
      storeJson['reducers'] = {};
      CWLogger.namedLog('Created missing reducers object in store.ts.');
    }

    // Add the RefreshControlSlice to the reducers object if not already present
    Map<String, dynamic> reducers = storeJson['reducers'];
    if (!reducers.containsKey(storeChanges['reducerChanges'].keys.first)) {
      reducers[storeChanges['reducerChanges'].keys.first] = storeChanges['reducerChanges'].values.first;
      CWLogger.namedLog('Added RefreshControlSlice to reducers in store.ts.');
    } else {
      CWLogger.namedLog('RefreshControlSlice already exists in reducers in store.ts.');
    }

    // Write the updated content back to store.ts
    await storeFile.writeAsString(json.encode(storeJson), mode: FileMode.write);
    CWLogger.namedLog('Updated store.ts with new whitelist and reducers.');
  }

}
