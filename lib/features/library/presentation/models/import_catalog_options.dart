class ImportCatalogOptions {
  final bool isCatalog;
  final bool registerChildFolders;

  const ImportCatalogOptions({
    required this.isCatalog,
    this.registerChildFolders = false,
  });
}
