import 'package:flutter/material.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 작업·도면 사진에서 여러 장 선택 후 URL 목록 반환.
Future<List<String>> showPlacePhotoUrlMultiPickDialog(
  BuildContext context, {
  required List<PlacePhotoEntry> photos,
  required String title,
}) {
  if (photos.isEmpty) return Future.value(const []);

  return showDialog<List<String>>(
    context: context,
    builder: (dCtx) {
      final selected = <int>{};
      return StatefulBuilder(
        builder: (dCtx, setSt) {
          void toggle(int i) {
            setSt(() {
              if (selected.contains(i)) {
                selected.remove(i);
              } else {
                selected.add(i);
              }
            });
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              height: dCtx.rs(400),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: dCtx.rsi(6),
                  mainAxisSpacing: dCtx.rsi(6),
                ),
                itemCount: photos.length,
                itemBuilder: (_, i) {
                  final e = photos[i];
                  final u = e.displayUrl.trim();
                  final sel = selected.contains(i);
                  return InkWell(
                    onTap: () => toggle(i),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel
                                  ? Theme.of(dCtx).colorScheme.primary
                                  : Theme.of(dCtx)
                                      .colorScheme
                                      .outlineVariant,
                              width: sel ? 2.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: u.isEmpty
                                ? const Icon(Icons.broken_image_outlined)
                                : Image.network(u, fit: BoxFit.cover),
                          ),
                        ),
                        if (sel)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.check_circle,
                              color: Theme.of(dCtx).colorScheme.primary,
                              size: dCtx.rs(22),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, const <String>[]),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        final urls = <String>[];
                        for (final i in selected) {
                          final u = photos[i].displayUrl.trim();
                          if (u.isNotEmpty) urls.add(u);
                        }
                        Navigator.pop(dCtx, urls);
                      },
                child: Text(
                  selected.isEmpty ? '추가' : '${selected.length}장 추가',
                ),
              ),
            ],
          );
        },
      );
    },
  ).then((v) => v ?? const []);
}
