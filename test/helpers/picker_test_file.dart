import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

final class PickerTestFile extends PlatformFile {
  PickerTestFile({
    required this.name,
    required this.uri,
    List<int> bytes = const [],
    this.knownLength,
    this._stream,
  }) : _bytes = Uint8List.fromList(bytes);

  @override
  final String name;
  @override
  final Uri uri;
  final int? knownLength;
  final Uint8List _bytes;
  final Stream<Uint8List> Function()? _stream;

  @override
  Never get xFile =>
      throw UnimplementedError('Use the picker stream in this fixture');
  @override
  int? lengthSync() => knownLength;
  @override
  Future<int?> length() async => knownLength;
  @override
  Future<Uint8List> readAsBytes() async => _bytes;
  @override
  Stream<Uint8List> readAsByteStream() =>
      _stream?.call() ?? Stream.value(_bytes);
}
