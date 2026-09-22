import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source de deep links, mockable en tests (pas de plugin).
abstract class AuthLinkSource {
  Future<Uri?> initialLink();
  Stream<Uri> get links;
}

class AppAuthLinkSource implements AuthLinkSource {
  AppAuthLinkSource({AppLinks? appLinks}) : _app = appLinks ?? AppLinks();

  final AppLinks _app;

  @override
  Future<Uri?> initialLink() async {
    try {
      return await _app.getInitialLink();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Uri> get links => _app.uriLinkStream;
}

/// Aucun lien — tests, desktop sans plugin, ou mode local.
class SilentAuthLinkSource implements AuthLinkSource {
  const SilentAuthLinkSource();

  @override
  Future<Uri?> initialLink() async => null;

  @override
  Stream<Uri> get links => const Stream.empty();
}

final authLinkSourceProvider = Provider<AuthLinkSource>(
  (ref) => AppAuthLinkSource(),
);
