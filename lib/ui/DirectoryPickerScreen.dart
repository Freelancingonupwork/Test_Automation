import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_package_integration/providers/statePorviders.dart';

class DirectoryPickerScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDirectory = ref.watch(directoryProvider);
    final isConfigurationAdded = ref.watch(isConfigured);

    return Scaffold(
      appBar: AppBar(title: Text('Directory Picker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Text(
                  selectedDirectory ?? 'No directory selected',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String? directoryPath = await FilePicker.platform.getDirectoryPath();
                print(directoryPath);
                if (directoryPath != null) {
                  if (await isValidFlutterProject(directoryPath)) {
                    ref.read(directoryProvider.notifier).update((state) => directoryPath);
                    Fluttertoast.showToast(
                      msg: "Valid Flutter project selected!",
                      toastLength: Toast.LENGTH_SHORT,
                      textColor: Colors.black45,
                      fontSize: 16.0,
                    );
                  } else {
                    Fluttertoast.showToast(
                      msg: "Selected directory is not a valid Flutter project.",
                      toastLength: Toast.LENGTH_SHORT,
                      textColor: Colors.black45,
                      fontSize: 16.0,
                    );
                  }
                }
              },
              child: Text('Select Directory'),
            ),
            !selectedDirectory.isEmpty
                ? ElevatedButton(
                    onPressed: () async {
                      if (selectedDirectory.toString().isEmpty) return;
                      final status = await Permission.manageExternalStorage.status;
                      print("Manage External Storage Permission Status: $status");
                      bool permissionsGranted = await requestStoragePermission();

                      if (!permissionsGranted) {
                        Fluttertoast.showToast(
                          msg: "Storage permissions are required to proceed.",
                          toastLength: Toast.LENGTH_SHORT,
                          textColor: Colors.black45,
                          fontSize: 16.0,
                        );
                        return;
                      } else {
                        print("Granted");
                      }

                      updatePubspecFile(selectedDirectory);
                    },
                    child: Text("Platform Specific configuration"))
                : SizedBox(),
            !selectedDirectory.isEmpty
                ? ElevatedButton(
              onPressed: () async {
                if (selectedDirectory.toString().isEmpty) return;

                showApiKeyDialog(context, selectedDirectory);
              },
              child: Text("Add API Key"),
            ): SizedBox(),
          ],
        ),
      ),
    );
  }

  Future<bool> isValidFlutterProject(String directoryPath) async {
    final pubspecFile = File('$directoryPath/pubspec.yaml');
    final androidFolder = Directory('$directoryPath/android');
    final iosFolder = Directory('$directoryPath/ios');

    if (await pubspecFile.exists() && await androidFolder.exists() && await iosFolder.exists()) {
      return true;
    }
    return false;
  }

  Future<bool> updatePubspecFile(String directoryPath) async {
    print("called");
    try {
      final pubspecFile = File('$directoryPath/pubspec.yaml');
      if (!(await pubspecFile.exists())) {
        print("Pub file not found");
        return false;
      } else {
        print("Pub file  found");
      }

      final content = await pubspecFile.readAsString();

      if (content.contains('google_maps_flutter')) {
        Fluttertoast.showToast(msg: "Dependency already exist", toastLength: Toast.LENGTH_SHORT, textColor: Colors.black45, fontSize: 16.0);
        runFlutterPubGet(directoryPath);
        return true;
      } else {
        runFlutterPubGet(directoryPath);
        print("Dependency already  not exist");
      }
      print("Dependency already exists updatedContent");

      final updatedContent = addDependency(content, 'google_maps_flutter: ^2.3.0');

      await pubspecFile.writeAsString(updatedContent);

      Fluttertoast.showToast(msg: "Added Dependency", toastLength: Toast.LENGTH_SHORT, textColor: Colors.black45, fontSize: 16.0);
      return true;
    } catch (e) {
      print('Error updating pubspec.yaml: $e');
      return false;
    }
  }

  String addDependency(String yamlContent, String dependency) {
    final lines = yamlContent.split('\n');
    final dependencyIndex = lines.indexWhere((line) => line.trim() == 'dependencies:');

    if (dependencyIndex != -1) {
      // Find the next line after 'dependencies:' that is not indented (end of dependencies block)
      int insertionIndex = dependencyIndex + 1;
      while (insertionIndex < lines.length && lines[insertionIndex].startsWith('   ')) {
        insertionIndex++;
      }

      lines.insert(insertionIndex, '  $dependency');
    } else {
      print('Error updating pubspec.yaml: else');
      lines.add('\ndependencies:\n  $dependency');
    }

    return lines.join('\n');
  }

  // Future<bool> requestPermissions() async {
  //   // Check and request permissions
  //   bool hasPermission = await requestStoragePermission();
  //
  //   var status = await Permission.storage.request();
  //   if (hasPermission) {
  //     return true;
  //   } else {
  //     print('Storage permission denied');
  //     return false;
  //   }
  // }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 11 and above
      if (await _isAndroid11OrHigher()) {
        final permission = Permission.manageExternalStorage;

        if (!await permission.isGranted) {
          final status = await permission.request();
          return status.isGranted;
        }
        return true;
      } else {
        // For Android 10 and below
        final permission = Permission.storage;

        if (!await permission.isGranted) {
          final status = await permission.request();
          return status.isGranted;
        }
        return true;
      }
    }
    return false; // For non-Android platforms
  }

  Future<bool> _isAndroid11OrHigher() async {
    if (Platform.isAndroid) {
      final version = int.parse((await Process.run('getprop', ['ro.build.version.sdk'])).stdout.trim());
      return version >= 30;
    }
    return false;
  }

  Future<void> runFlutterPubGet(String projectPath) async {
    try {
      Directory.current = Directory(projectPath);

      final result = await Process.run('flutter', ['pub', 'get']);

      if (result.exitCode == 0) {
        print('Packages installed successfully!');
      } else {
        print('Error: ${result.stderr}');
      }
    } catch (e) {
      print('Error running flutter pub get: $e');
    }
  }

  Future<void> addMapsConfigForAndroid(String projectPath, String apiKey) async {
    try {
      final manifestPath = '$projectPath/android/app/src/main/AndroidManifest.xml';
      final manifestFile = File(manifestPath);

      if (!manifestFile.existsSync()) {
        print('Error: AndroidManifest.xml not found at $manifestPath');
        return;
      }

      String manifestContent = await manifestFile.readAsString();

      // Ensure permissions exist
      if (!manifestContent.contains('android.permission.INTERNET')) {
        manifestContent = manifestContent.replaceFirst(
          '<manifest',
          '''
<manifest>
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
        ''',
        );
      }

      // Check if API key already exists
      final apiKeyPattern = RegExp(
          r'<meta-data\s+android:name="com.google.android.maps.v2.API_KEY"\s+android:value="(.*?)"\s*/>');
      if (apiKeyPattern.hasMatch(manifestContent)) {
        // Replace existing API key
        manifestContent = manifestContent.replaceAllMapped(apiKeyPattern, (match) {
          return '<meta-data android:name="com.google.android.maps.v2.API_KEY" android:value="$apiKey" />';
        });
        print('Updated existing API key in AndroidManifest.xml');
      } else {
        // Add new API key entry
        manifestContent = manifestContent.replaceFirst(
          '<application',
          '''
        <application>
        <meta-data
            android:name="com.google.android.maps.v2.API_KEY"
            android:value="$apiKey" />
        ''',
        );
        print('Added new API key to AndroidManifest.xml');
      }

      await manifestFile.writeAsString(manifestContent);
      print('AndroidManifest.xml updated successfully!');
    } catch (e) {
      print('Error updating AndroidManifest.xml: $e');
    }
  }

  Future<void> addMapConfigFoIOS(String projectPath, String apiKey) async {
    try {
      final plistPath = '$projectPath/ios/Runner/Info.plist';
      final plistFile = File(plistPath);

      if (!plistFile.existsSync()) {
        print('Error: Info.plist not found at $plistPath');
        return;
      }

      String plistContent = await plistFile.readAsString();

      // Check if GMSAPIKey already exists
      final apiKeyPattern = RegExp(r'<key>GMSAPIKey<\/key>\s*<string>(.*?)<\/string>');
      if (apiKeyPattern.hasMatch(plistContent)) {
        // Replace existing API key
        plistContent = plistContent.replaceAllMapped(apiKeyPattern, (match) {
          return '<key>GMSAPIKey</key>\n<string>$apiKey</string>';
        });
        print('Updated existing API key in Info.plist');
      } else {
        // Add new API key entry
        final apiKeyEntry = '''
        <key>GMSAPIKey</key>
        <string>$apiKey</string>
      ''';

        plistContent = plistContent.replaceFirst(
          '</dict>',
          '''
        $apiKeyEntry
        </dict>
        ''',
        );
        print('Added new API key to Info.plist');
      }

      await plistFile.writeAsString(plistContent);
      print('Info.plist updated successfully!');
    } catch (e) {
      print('Error updating Info.plist: $e');
    }
  }


  Future<void> showApiKeyDialog(BuildContext context, String projectPath) async {
    final TextEditingController apiKeyController = TextEditingController();

    // Check if the API key is already configured
    final isApiKeyConfiguredAndroid = await checkAndroidApiKeyConfigured(projectPath);
    final isApiKeyConfiguredIOS = await checkIOSApiKeyConfigured(projectPath);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Google Maps API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isApiKeyConfiguredAndroid || isApiKeyConfiguredIOS)
                const Text(
                  'An API key is already configured. You can skip or override it.',
                  style: TextStyle(color: Colors.orange),
                ),
              SizedBox(height: 16),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Enter Google Maps API Key',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            if (isApiKeyConfiguredAndroid || isApiKeyConfiguredIOS)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Skip'),
              ),
            ElevatedButton(
              onPressed: () async {
                final apiKey = apiKeyController.text.trim();
                if (apiKey.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('API Key cannot be empty')),
                  );
                  return;
                }

                await addMapsConfigForAndroid(projectPath, apiKey);
                await addMapConfigFoIOS(projectPath, apiKey);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('API Key configured successfully')),
                );

                Navigator.of(context).pop();
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  //Android
  Future<bool> checkAndroidApiKeyConfigured(String projectPath) async {
    try {
      final manifestPath = '$projectPath/android/app/src/main/AndroidManifest.xml';
      final manifestFile = File(manifestPath);

      if (!manifestFile.existsSync()) {
        print('Error: AndroidManifest.xml not found at $manifestPath');
        return false;
      }

      String manifestContent = await manifestFile.readAsString();
      return manifestContent.contains('com.google.android.maps.v2.API_KEY');
    } catch (e) {
      print('Error checking AndroidManifest.xml: $e');
      return false;
    }
  }

  Future<bool> checkIOSApiKeyConfigured(String projectPath) async {
    try {
      final plistPath = '$projectPath/ios/Runner/Info.plist';
      final plistFile = File(plistPath);

      if (!plistFile.existsSync()) {
        print('Error: Info.plist not found at $plistPath');
        return false;
      }

      String plistContent = await plistFile.readAsString();
      return plistContent.contains('<key>GMSAPIKey</key>');
    } catch (e) {
      print('Error checking Info.plist: $e');
      return false;
    }
  }
}
