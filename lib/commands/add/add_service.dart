import 'dart:convert';
import 'dart:io';

import 'package:cli_spin/cli_spin.dart';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';
import 'package:react_native/config/plugin_config.dart';

import '../../config/runtime_config.dart';
import '../../model/specification.dart';

class ReactNativeService extends Command {
  ReactNativeService(super.args);

  @override
  String get description => "Manage Services for React Native project.";

  @override
  Future<void> run() async {
    CWLogger.i.progress("Looking for available Services");

    List<String>? dirs = await GitService.getGitLabBranches(
      ReactNativeConfig.i.archManagerProjectID,
      TokenService().accessToken!,
    );

    if (dirs == null || dirs.isEmpty) {
      CWLogger.namedLog(
        'No services found!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }
    List<String> utilsBranches = dirs
        .where((branch) => branch.startsWith('service/'))
        .map((branch) => branch.replaceFirst('service/', ''))
        .toList();

    if (utilsBranches.isEmpty) {
      CWLogger.namedLog(
        'No services found in the "service/" directory!',
        loggerColor: CWLoggerColor.yellow,
      );
      exit(1);
    }

    CWLogger.i.stdout("Please select the Service you want to use :");
    Menu featureMenu = Menu(utilsBranches);
    int idx = featureMenu.choose().index;

    String selectedService = 'service/${utilsBranches[idx]}';

    await _handleServiceAndSpecification(selectedService);
  }

  Future<void> _handleServiceAndSpecification(String serviceName) async {
    CliSpin featureLoader =
    CliSpin(text: "Adding $serviceName to the project").start();

    try {
      String filePath = 'specification_config.json';
      String? specsFileContent = await GitService.getGitLabFileContent(
        projectId: ReactNativeConfig.i.pilotRepoProjectID,
        filePath: filePath,
        branch: serviceName,
        token: TokenService().accessToken!,
      );

      if (specsFileContent != null) {
        Map<String, dynamic> specificationData = json.decode(specsFileContent);
        List<dynamic> serviceFilePaths = specificationData['filePath'];
        for (String serviceFilePath in serviceFilePaths) {
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

        await SpecificationUpdater.updateSpecifications(serviceName);

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
          'Error downloading service $serviceName or updating specifications: $e');
    }
  }
}
