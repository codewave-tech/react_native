import 'dart:convert';
import 'dart:io';
import 'package:cw_core/cw_core.dart';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:yaml/yaml.dart';
import '../../config/plugin_config.dart';
import '../../config/runtime_config.dart';
import '../../utils/cli_spinner.dart';
import '../../utils/package_json.dart'; // Import the new utils file

class ReactNativeInit extends Command {
  ReactNativeInit(super.args);

  @override
  String get description => "Set up standard or custom project architectures.";

  static String apxInitializationType = 'initialization-type';
  static String apxConfigFilePath = 'config-file-path';

  @override
  Future<void> run() async {

    String branch = 'main';
    SimpleSpinner spinner = SimpleSpinner();

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
    await _createTimestampConfigFile();
    spinner.start("Adapting architecture $branch in the project");

    List<String> directoriesToDownload = [
      'components', 'hooks', 'service', 'redux', 'patches', 'utils', 'apiService', 'config', 'constants'
    ];

    for (var directory in directoriesToDownload) {
      await GitService.downloadDirectoryContents(
        projectId: ReactNativeConfig.i.archManagerProjectID,
        branch: branch,
        directoryPath: directory,
        downloadPathBase: RuntimeConfig().commandExecutionPath,
        accessToken: TokenService().accessToken!,
        isProd: ReactNativeConfig.i.pluginEnvironment == PluginEnvironment.prod,
      );
    }
    List<String> configFilesToDownload = [
      '.env.development',
      '.env.preview',
      '.env.production',
      '.gitlab-ci.yml',
      '.nvmrc',
      'babel.config.js',
      'metro.config.js',
      'declarations.d.ts',
      'eas.json',
    ];

    for (var file in configFilesToDownload) {
      String? fileContent = await GitService.getGitLabFileContent(
        projectId: ReactNativeConfig.i.archManagerProjectID,
        filePath: file,
        branch: branch,
        token: TokenService().accessToken!,
      );

      if (fileContent != null) {
        String localPath = '${RuntimeConfig().commandExecutionPath}/$file';
        File localFile = File(localPath);

        await localFile.create(recursive: true);
        await localFile.writeAsString(fileContent);
        CWLogger.i.trace('Downloaded $file');
      } else {
        CWLogger.i.trace('Failed to download file: $file');
      }
    }
    await PackageJsonUtils.mergeRemotePackageJson(
        ReactNativeConfig.i.archManagerProjectID,
        branch
    );
    spinner.stop(isSuccess: true,successMessage: "Project now follows the selected architecture");

    return;
  }

  Future<void> _createTimestampConfigFile() async {
    const String pubspecUrl = 'https://raw.githubusercontent.com/codewave-tech/react_native/main/pubspec.yaml';
    HttpEngineResponse response = await HttpEngine.call(
      payload: HttpEnginePayload(
        url: pubspecUrl,
        requestType: RequestType.get,
      ),
    );

    if (response.type == ResponseType.success) {
      var pubspecData = loadYaml(response.body??"");

      String pluginName = pubspecData['name'] ?? 'Unknown Plugin';
      String pluginVersion = pubspecData['version'] ?? '0.0.0';
      String pluginDescription = pubspecData['description'] ?? '';

      DateTime now = DateTime.now();
      String formattedDate = now.toIso8601String();

      stdout.write('Enter project name: ');
      String projectName = stdin.readLineSync() ?? '';

      stdout.write('Enter project ID: ');
      String projectId = stdin.readLineSync() ?? '';

      String architectureUsed = "main";

      Map<String, dynamic> configContent = {
        'init_time': formattedDate,
        'plugin_name': pluginName,
        'plugin_version': pluginVersion,
        'plugin_description': pluginDescription,
        'project_name': projectName,
        'project_id': projectId,
        'architecture_used': architectureUsed,
      };

      String configFilePath = '${RuntimeConfig().commandExecutionPath}/cwa_config.json';

      try {
        File configFile = File(configFilePath);
        await configFile.create(recursive: true); // Create file if not exists
        await configFile.writeAsString(jsonEncode(configContent));

        CWLogger.i.trace('Timestamp config file created at $configFilePath');
      } catch (e) {
        CWLogger.i.trace('Failed to create timestamp config file: $e');
      }
    } else {
      CWLogger.i.trace('Failed to fetch pubspec.yaml from GitLab.');
    }
  }


}
