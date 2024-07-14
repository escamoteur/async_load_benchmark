import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

class IsolateInitData {
  /// this port is needed to wire up the communication with the isolate
  final SendPort initSendPort;
  final SendPort resultPort;

  IsolateInitData({
    required this.initSendPort,
    required this.resultPort,
  });
}

class FileLoadRequest {
  final int id;
  final String filePath;
  bool loadSync;
  FileLoadRequest({
    required this.id,
    required this.filePath,
    required this.loadSync,
  });
}

class LoadResult {
  final int id;
  final TransferableTypedData data;

  LoadResult({required this.data, required this.id});
}

class TestIsolateLoader {
  int requestCounter = 0;
  final Map<int, Completer<Uint8List>> _completers = {};

  /// this fields are only accessed from main isolate
  late Isolate isolate;
  late SendPort toIsolate;
  final ReceivePort resultPort = ReceivePort();

  TestIsolateLoader() {
    resultPort.listen((message) {
      if (message is LoadResult) {
        final completer = _completers.remove(message.id);
        if (completer != null) {
          completer.complete(message.data.materialize().asUint8List());
        }
      }
    });
  }

  Future<Uint8List> loadFile(String filePath, bool loadSync) async {
    final completer = Completer<Uint8List>();
    final id = requestCounter++;
    _completers[id] = completer;
    toIsolate
        .send(FileLoadRequest(id: id, filePath: filePath, loadSync: loadSync));
    return completer.future;
  }

  Future<void> init() async {
    ReceivePort initPort = ReceivePort();

    isolate = await Isolate.spawn(
      isolateHandler,
      IsolateInitData(
        initSendPort: initPort.sendPort,
        resultPort: resultPort.sendPort,
      ),
    );

    /// Wait to receive the communication port of the just created isolate back.
    toIsolate = await initPort.first as SendPort;
  }

  void kill() {
    isolate.kill();
  }

  static late _IsolateMessageHandler _messageHandler;

  static void isolateHandler(IsolateInitData initData) {
    /// this here is the code that runs inside the isolate
    _messageHandler = _IsolateMessageHandler();
    _messageHandler.run(initData);
  }
}

class _IsolateMessageHandler {
  void run(IsolateInitData initData) async {
    final SendPort initSendPort = initData.initSendPort;

    /// Port we pass back to the mainisolate to have bidirection communication
    final ReceivePort fromMainIsolate = ReceivePort();
    late final SendPort resultPort = initData.resultPort;
    initSendPort.send(fromMainIsolate.sendPort);

    fromMainIsolate.listen((message) async {
      if (message is FileLoadRequest) {
        final file = File(message.filePath);
        if (message.loadSync) {
          final data = file.readAsBytesSync();
          resultPort.send(
            LoadResult(
              id: message.id,
              data: TransferableTypedData.fromList([data]),
            ),
          );
          return;
        } else {
          file.readAsBytes().then((data) {
            resultPort.send(
              LoadResult(
                id: message.id,
                data: TransferableTypedData.fromList([data]),
              ),
            );
          });
        }
      }
    });
  }
}
