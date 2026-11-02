/// Immutable, bundled examples. These are never MediaItems or database records.
enum SampleKind { photos, art, music, text }

class SampleCatalog {
  const SampleCatalog(this.id, this.kind, this.assets);

  final String id;
  final SampleKind kind;
  final List<String> assets;

  static const version = 1;

  static List<SampleCatalog> forLocale(String languageCode) => [
    const SampleCatalog('travel', SampleKind.photos, [
      'assets/images/samples/photo_book/spring_trip_coast.png',
      'assets/images/samples/photo_book/spring_trip_evening.png',
      'assets/images/samples/photo_book/spring_trip_morning.png',
    ]),
    const SampleCatalog('art', SampleKind.art, [
      'assets/images/samples/illustration_collection/moonlit_reader.png',
      'assets/images/samples/illustration_collection/botanical_atelier.png',
      'assets/images/samples/illustration_collection/starlight_observatory.png',
    ]),
    const SampleCatalog('music-cover', SampleKind.music, [
      'assets/images/samples/music_album/night_focus_cover.png',
    ]),
    SampleCatalog('reading', SampleKind.text, [
      'assets/text/samples/text_book/${languageCode == 'ja' ? 'ja' : 'en'}/reading_notes.md',
    ]),
  ];
}
