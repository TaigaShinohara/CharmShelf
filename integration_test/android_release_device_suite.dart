import 'package:flutter_test/flutter_test.dart';

import '../test/features/library/data/services/library_backup_service_test.dart'
    as backup;
import 'reference_migration_device_test.dart' as migration;
import 'release_smoke_test.dart' as smoke;

// Use a fresh numbered performanceqa package and flutter drive --keep-app-running.
// The flag prevents Flutter's default exit cleanup from uninstalling a QA app.
void main() {
  smoke.main();
  migration.main();
  group('physical device backup and restore', backup.main);
}
