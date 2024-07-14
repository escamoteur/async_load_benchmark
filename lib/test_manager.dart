import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:async_load_benchmark/test_file_service.dart';
import 'package:async_load_benchmark/test_isolate.dart';

class TestManager {
  final TestIsolateLoader _isolateLoader = TestIsolateLoader();
  final TestFileService _fileService = TestFileService();

  Future<void> intialize() async {
    await _fileService.init();
    await _isolateLoader.init();
  }

  List<Meassuerment> meassuerments = [];
  int totalTime = 0;

  void reset() {
    meassuerments.clear();
    totalTime = 0;
  }

  Map<String, Map<String, int>> processMeasuerments() {
    /// get min, max, avg, median and total for each field
    final syncIsolate = meassuerments.map((e) => e.syncIsolate).toList();
    final asyncIsolate = meassuerments.map((e) => e.asyncIsolate).toList();
    final async = meassuerments.map((e) => e.async).toList();
    final sync = meassuerments.map((e) => e.sync).toList();
    final isolateRun = meassuerments.map((e) => e.isolateRun).toList();
    final fileSizes = meassuerments.map((e) => e.fileSize).toList();

    final results = {
      'syncIsolate': {
        'min': syncIsolate
            .reduce((value, element) => value < element ? value : element),
        'max': syncIsolate
            .reduce((value, element) => value > element ? value : element),
        'avg': syncIsolate.reduce((value, element) => value + element) ~/
            syncIsolate.length,
        'median': syncIsolate[syncIsolate.length ~/ 2],
      },
      'asyncIsolate': {
        'min': asyncIsolate
            .reduce((value, element) => value < element ? value : element),
        'max': asyncIsolate
            .reduce((value, element) => value > element ? value : element),
        'avg': asyncIsolate.reduce((value, element) => value + element) ~/
            asyncIsolate.length,
        'median': asyncIsolate[asyncIsolate.length ~/ 2],
      },
      'async': {
        'min':
            async.reduce((value, element) => value < element ? value : element),
        'max':
            async.reduce((value, element) => value > element ? value : element),
        'avg':
            async.reduce((value, element) => value + element) ~/ async.length,
        'median': async[async.length ~/ 2],
      },
      'sync': {
        'min':
            sync.reduce((value, element) => value < element ? value : element),
        'max':
            sync.reduce((value, element) => value > element ? value : element),
        'avg': sync.reduce((value, element) => value + element) ~/ sync.length,
        'median': sync[sync.length ~/ 2],
      },
      'isolateRun': {
        'min': isolateRun
            .reduce((value, element) => value < element ? value : element),
        'max': isolateRun
            .reduce((value, element) => value > element ? value : element),
        'avg': isolateRun.reduce((value, element) => value + element) ~/
            isolateRun.length,
        'median': isolateRun[isolateRun.length ~/ 2],
      },
      'fileSizes': {
        'min': fileSizes
            .reduce((value, element) => value < element ? value : element),
        'max': fileSizes
            .reduce((value, element) => value > element ? value : element),
        'avg': fileSizes.reduce((value, element) => value + element) ~/
            fileSizes.length,
        'median': fileSizes[fileSizes.length ~/ 2],
      },
    };

    return results;
  }

  Future<void> loadFilesSequentially() async {
    final stopwatch = Stopwatch()..start();
    for (final filePath in _fileService.testFiles) {
      await timeSingleFileLoad(filePath);
    }
    stopwatch.stop();
    totalTime = stopwatch.elapsedMilliseconds;
  }

  Future<void> loadFilesConcurrently() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final waitingFutures =
        _fileService.testFiles.map((filePath) => timeSingleFileLoad(filePath));
    await Future.wait(waitingFutures);
    stopwatch.stop();
    totalTime = stopwatch.elapsedMilliseconds;
  }

  Future<void> loadFilesInBatches(int batchSize) async {
    final stopwatch = Stopwatch()..start();
    final files = _fileService.testFiles;
    for (int i = 0; i < files.length; i += batchSize) {
      final batch = files.skip(i).take(batchSize).toList();
      final waitingFutures =
          batch.map((filePath) => timeSingleFileLoad(filePath));
      await Future.wait(waitingFutures);
    }
    stopwatch.stop();
    totalTime = stopwatch.elapsedMilliseconds;
  }

  Future<Meassuerment> timeSingleFileLoad(String path) async {
    final file = File(path);
    final result = Meassuerment();

    /// preload file to disk cache
    final data = await file.readAsBytes();
    result.fileSize = data.length;
    final stopwatch = Stopwatch()..start();

    /// load from isolate synchronously
    await _isolateLoader.loadFile(path, true);
    stopwatch.stop();
    result.syncIsolate = stopwatch.elapsedMicroseconds;

    stopwatch.reset();
    stopwatch.start();

    /// load from isolate asynchronously
    await _isolateLoader.loadFile(path, false);
    stopwatch.stop();
    result.asyncIsolate = stopwatch.elapsedMicroseconds;

    stopwatch.reset();
    stopwatch.start();

    /// load file asynchronously
    await file.readAsBytes();
    stopwatch.stop();
    result.async = stopwatch.elapsedMicroseconds;

    stopwatch.reset();
    stopwatch.start();

    /// load file synchronously
    file.readAsBytesSync();
    stopwatch.stop();
    result.sync = stopwatch.elapsedMicroseconds;

    stopwatch.reset();
    stopwatch.start();

    /// load file with Isolate.run
    await loadFileIsolateRun(path);
    stopwatch.stop();
    result.isolateRun = stopwatch.elapsedMicroseconds;

    return result;
  }

  Future<Uint8List> loadFileIsolateRun(String path) {
    File file = File(path);
    return Isolate.run(() => file.readAsBytesSync());
  }
}

class Meassuerment {
  int fileSize = 0;
  int syncIsolate = 0;
  int asyncIsolate = 0;
  int async = 0;
  int sync = 0;
  int isolateRun = 0;
}
