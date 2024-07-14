import 'dart:io';

import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';

class TestFileService {
  List<String> testFiles = [];
  static const testFileFolder = 'test_files_async_download';
  late String testFolderPath;
  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    testFolderPath = '${directory.path}/$testFileFolder';
    final testFileDir = Directory(testFileFolder);
    if (!await testFileDir.exists()) {
      await testFileDir.create();
      await populateTestFiles();
    }
    testFiles = await testFileDir.list().map((e) => e.path).toList();
  }

  Future<void> populateTestFiles() async {
    for (int i = 0; i < 100; i++) {
      await downloadTestFile('https://picsum.photos/id/$i/1080');
    }
    for (int i = 0; i < 100; i++) {
      await downloadTestFile('https://picsum.photos/id/$i/720');
    }
    for (int i = 0; i < 100; i++) {
      await downloadTestFile('https://picsum.photos/id/$i/480');
    }
    for (int i = 0; i < 100; i++) {
      await downloadTestFile('https://picsum.photos/id/$i/1440');
    }
  }

  final _client = Client();

  Future<void> downloadTestFile(String url) async {
    final Uri resolved = Uri.base.resolve(url);

    final response = await _client.get(resolved);
    if (response.statusCode == 200) {
      final imageData = response.bodyBytes;
      final file =
          File('$testFolderPath/${DateTime.now().millisecondsSinceEpoch}');
      await file.writeAsBytes(imageData);
    }
  }
}
