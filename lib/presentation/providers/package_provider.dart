import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/package_catalog.dart';

final packageCatalogProvider =
    NotifierProvider<PackageCatalogNotifier, PackageCatalog?>(
      PackageCatalogNotifier.new,
    );

class PackageCatalogNotifier extends Notifier<PackageCatalog?> {
  @override
  PackageCatalog? build() => null;

  void setCatalog(PackageCatalog catalog) => state = catalog;

  void clear() => state = null;
}
