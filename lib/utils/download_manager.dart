import 'dart:io';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import '../config/plugin_config.dart';
import '../config/runtime_config.dart';

class DownloadManager {
  // Singleton pattern for centralized download management
  static final DownloadManager _instance = DownloadManager._internal();

  factory DownloadManager() {
    return _instance;
  }

  DownloadManager._internal();

  // Method to download individual file
  Future<void> downloadFile(String serviceFilePath, String serviceName) async {
    String? fileContent = await GitService.getGitLabFileContent(
      projectId: ReactNativeConfig.i.pilotRepoProjectID,
      filePath: serviceFilePath,
      branch: serviceName,
      token: TokenService().accessToken!,
    );

    if (fileContent != null) {
      String localFilePath =
          '${RuntimeConfig().commandExecutionPath}/$serviceFilePath';
      File localFile = File(localFilePath);

      if (localFile.existsSync()) {
        CWLogger.i
            .trace('$serviceFilePath already exists, skipping download.');
      } else {
        await localFile.create(recursive: true);
        await localFile.writeAsString(fileContent);
        CWLogger.i.trace('Downloaded $serviceFilePath successfully.');
      }
    } else {
      CWLogger.i.trace('Failed to fetch $serviceFilePath.');
    }
  }

  // Method to download a directory
  Future<void> downloadDirectory(String serviceFolderPath, String serviceName) async {
    try {
      await GitService.downloadDirectoryContents(
        projectId: ReactNativeConfig.i.pilotRepoProjectID,
        branch: serviceName,
        directoryPath: serviceFolderPath,
        downloadPathBase: RuntimeConfig().commandExecutionPath,
        accessToken: TokenService().accessToken!,
      );
      CWLogger.i.trace('Downloaded directory $serviceFolderPath successfully.');
    } catch (e) {
      CWLogger.i.trace('Failed to download directory $serviceFolderPath: $e');
    }
  }
}
