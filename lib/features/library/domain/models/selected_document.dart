/// A system-selected document. Its URI remains opaque to the import flow.
class SelectedDocument {
  const SelectedDocument({
    required this.uri,
    required this.name,
    this.size,
    this.mimeType,
    this.ownsGrant = false,
  });

  final Uri uri;
  final String name;
  final int? size;
  final String? mimeType;
  final bool ownsGrant;
}

class PickedFolder {
  const PickedFolder({required this.uri, this.ownsGrant = false});

  final Uri uri;
  final bool ownsGrant;
}
