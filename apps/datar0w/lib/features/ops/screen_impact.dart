import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../identity/controller.dart';
import '../../ops/controller.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

Future<void> showImpactDialog(
  BuildContext context,
  WidgetRef ref, {
  required String boatId,
}) async {
  final note = TextEditingController();
  String? photoPath;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: DeckColors.surfaceHigh,
            title: const Text('SIGNALER UN IMPACT'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: note,
                  maxLength: 140,
                  decoration: const InputDecoration(
                    labelText: 'Ce qui s’est passé',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final x = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      imageQuality: 70,
                    );
                    if (x == null) return;
                    final root = await ref.read(opsStoreProvider).root();
                    final dest = File(
                      p.join(root.path, 'impacts', p.basename(x.path)),
                    );
                    await dest.parent.create(recursive: true);
                    await File(x.path).copy(dest.path);
                    setSt(() => photoPath = dest.path);
                  },
                  child: Text(
                    photoPath == null ? 'PHOTO' : 'PHOTO OK',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () async {
                  final who = ref.read(identityProvider).activeRower?.id ??
                      'coach-local';
                  await ref.read(opsProvider.notifier).reportImpact(
                        boatId: boatId,
                        reportedBy: who,
                        note: note.text.trim(),
                        photoPath: photoPath,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('ENVOYER'),
              ),
            ],
          );
        },
      );
    },
  );
  note.dispose();
}

class SignalImpactButton extends ConsumerWidget {
  const SignalImpactButton({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: () => showImpactDialog(context, ref, boatId: boatId),
      child: const Text('SIGNALER UN IMPACT'),
    );
  }
}

class MaintenanceQueueScreen extends ConsumerWidget {
  const MaintenanceQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ident = ref.watch(identityProvider);
    final ops = ref.watch(opsProvider);
    final admin = canEditPark(ident, ref.watch(boatConfigProvider).role);

    return DeckScaffold(
      title: 'MAINTENANCE',
      subtitle: 'Impacts signalés',
      body: ops.openImpacts.isEmpty
          ? const Center(
              child: Text(
                'Aucun signalement ouvert.',
                style: TextStyle(color: DeckColors.muted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (final r in ops.openImpacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: DeckColors.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            ident.boatById(r.boatId)?.name ?? r.boatId,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            r.note.isEmpty ? 'sans note' : r.note,
                            style: const TextStyle(color: DeckColors.muted),
                          ),
                          if (r.photoPath != null &&
                              File(r.photoPath!).existsSync())
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Image.file(
                                File(r.photoPath!),
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          if (admin) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => ref
                                  .read(opsProvider.notifier)
                                  .clearImpact(r.id),
                              child: const Text('LEVER LE FLAG'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
