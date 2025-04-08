import 'dart:convert';
import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:cwa_plugin_core/cwa_plugin_core.dart';

class PackageJsonUtils {
  // Method to fetch remote package.json content, parse and merge with local one
  static Future<void> mergeRemotePackageJson(
      String projectId,
      String branchName,
      ) async {
    CWLogger.i.stdout("Merging package.json from GitLab...");

    // Fetch remote package.json content
    String? remotePackageJsonContent = await GitService.getGitLabFileContent(
      projectId: projectId,
      filePath: 'package.json',
      branch: branchName,
      token: TokenService().accessToken!,
    );

    if (remotePackageJsonContent == null) {
      CWLogger.i.stderr("Error fetching package.json from GitLab.");
      exit(1);
    }

    // Parse local and remote package.json files
    final File localPackageJsonFile = File('package.json');
    Map<String, dynamic> localPackage = jsonDecode(localPackageJsonFile.readAsStringSync());
    Map<String, dynamic> remotePackage = jsonDecode(remotePackageJsonContent);

    // Merge dependencies
    mergePackageSections(localPackage, remotePackage, 'dependencies');
    mergePackageSections(localPackage, remotePackage, 'devDependencies');
    mergePackageSections(localPackage, remotePackage, 'scripts');

    // Write back the merged content into local package.json
    localPackageJsonFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(localPackage));

    CWLogger.i.stdout("Successfully merged package.json with remote content.");

    // Run yarn install if required
    await runYarnInstall();
  }

  // Helper function to merge specific sections of package.json (dependencies, devDependencies, etc.)
  static void mergePackageSections(Map<String, dynamic> local, Map<String, dynamic> remote, String key) {
    if (!remote.containsKey(key)) return;
    if (!local.containsKey(key)) local[key] = {};

    (remote[key] as Map).forEach((k, v) {
      if (!local[key].containsKey(k)) {
        local[key][k] = v;
      }
    });
  }

  // Helper function to run yarn install after merging
  static Future<void> runYarnInstall() async {
    try {
      CWLogger.i.stdout("Running yarn install...");
      await Shell().run('yarn install');
      CWLogger.i.stdout("yarn install completed successfully.");
    } catch (e) {
      CWLogger.i.stderr("Error running yarn install: $e");
      exit(1);
    }
  }
}
