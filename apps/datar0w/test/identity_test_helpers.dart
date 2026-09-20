import 'dart:io';

import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/ops/controller.dart';
import 'package:datar0w/ops/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Directory newIdentityDir() {
  final dir = Directory(
    '/tmp/datar0w-id-${DateTime.now().microsecondsSinceEpoch}',
  );
  dir.createSync(recursive: true);
  return dir;
}

Override identityStoreOverride({Directory? root}) {
  final dir = root ?? newIdentityDir();
  return identityStoreProvider.overrideWith((ref) => IdentityStore(root: dir));
}

Override opsStoreOverride({Directory? root}) {
  final dir = root ?? newIdentityDir();
  return opsStoreProvider.overrideWith((ref) => OpsStore(root: dir));
}
