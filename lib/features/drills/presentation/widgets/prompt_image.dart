import 'dart:typed_data';

import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/features/content/data/content_store.dart';
import 'package:bah_francais/features/content/domain/content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prompt_image.g.dart';

/// An image, read once and kept, so showing a card again is instant.
@Riverpod(keepAlive: true)
Future<ContentImage?> drillImage(Ref ref, String id) {
  final db = ref.watch(appDatabaseProvider);
  return ContentStore(db, db).image(id);
}

/// The image a Vocabulaire card asks the user to name. Its screen-reader
/// label never names the word.
class PromptImage extends ConsumerWidget {
  const PromptImage(this.imageId, {super.key});

  final String imageId;

  /// Readable at this size, as the artwork rules require.
  static const size = 200.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(drillImageProvider(imageId)).value;
    return Semantics(
      image: true,
      label: Strings.accessibilityPromptImage,
      child: SizedBox.square(
        dimension: size,
        child: switch (image) {
          null => const SizedBox.shrink(),
          ContentImage(format: ImageFormat.svg, :final svg?) =>
            SvgPicture.string(svg, excludeFromSemantics: true),
          ContentImage(:final bytes?) => Image.memory(
            Uint8List.fromList(bytes),
            excludeFromSemantics: true,
            fit: BoxFit.contain,
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}
