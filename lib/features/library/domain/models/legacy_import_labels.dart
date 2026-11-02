/// Metadata from the retired device-file organizer, applied only during import.
class LegacyImportLabels {
  const LegacyImportLabels({
    required this.tags,
    required this.catalog,
    required this.favorite,
  });
  final List<String> tags;
  final String catalog;
  final bool favorite;
}
