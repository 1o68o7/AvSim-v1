import 'dart:io';

import 'package:flutter/material.dart';

import '../identity/models.dart';
import '../theme/deck_theme.dart';

Color? clubColor(int? v) => v == null ? null : Color(v);

int? parseHexColor(String raw) {
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  return int.tryParse(s, radix: 16);
}

String hexColor(int? v) {
  if (v == null) return '';
  return '#${v.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

class ClubBanner extends StatelessWidget {
  const ClubBanner({super.key, required this.club, this.compact = false});

  final Club club;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = clubColor(club.primaryColor) ?? DeckColors.amber;
    final path = club.crestPath;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: primary.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          if (path != null && File(path).existsSync())
            Image.file(File(path), width: compact ? 36 : 56, height: compact ? 36 : 56, fit: BoxFit.cover)
          else
            Icon(Icons.shield_outlined, color: primary, size: compact ? 28 : 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.fullName?.isNotEmpty == true ? club.fullName! : club.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (club.slogan != null && club.slogan!.isNotEmpty)
                  Text(
                    club.slogan!,
                    style: TextStyle(color: primary, fontSize: 12),
                  ),
                if (club.licenceCountApprox != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: DeckColors.hairline),
                      ),
                      child: Text(
                        '~${club.licenceCountApprox} licenciés',
                        style: const TextStyle(
                          color: DeckColors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
