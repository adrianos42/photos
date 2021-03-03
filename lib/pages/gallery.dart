import 'dart:async';
import 'dart:io';
import 'package:desktop/desktop.dart';
import 'package:flutter/foundation.dart';
import 'package:collections/collections.dart';
import 'items.dart';

class GalleryPage extends StatelessWidget {
  GalleryPage(this.photos, this.directoryEntry, {Key? key}) : super(key: key);

  final Photos photos;
  final DirectoryEntry directoryEntry;

  List<PictureEntry> get pictureEntries => directoryEntry.items
      .where((element) => element.variant == Directory.picture)
      .map((e) => e.value as PictureEntry)
      .toList();

  List<DirectoryEntry> get directoryEntries => directoryEntry.items
      .where((element) => element.variant == Directory.directory)
      .map((e) => e.value as DirectoryEntry)
      .toList();

  Future<PictureEntry?> _requestPrevious(PictureEntry id) async {
    for (var i = 0; i < pictureEntries.length; i += 1) {
      if (id == pictureEntries[i]) {
        final index = i - 1;
        if (index >= 0) {
          return pictureEntries[index];
        }
      }
    }
  }

  Future<PictureEntry?> _requestNext(PictureEntry id) async {
    for (var i = 0; i < pictureEntries.length; i += 1) {
      if (id == pictureEntries[i]) {
        final index = i + 1;
        if (index > 0 && index < pictureEntries.length) {
          return pictureEntries[index];
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ScrollController();

    return Padding(
      padding: EdgeInsets.only(top: 16.0),
      child: Scrollbar(
        controller: controller,
        child: GridView.custom(
          controller: controller,
          padding: const EdgeInsets.all(4.0),
          cacheExtent: 2000,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisSpacing: 2.0,
            crossAxisSpacing: 2.0,
            childAspectRatio: 1.2,
          ),
          childrenDelegate: SliverChildListDelegate.fixed(
            [
              ...directoryEntries.map(
                (dir) => ItemFolder(
                  photos,
                  dir: dir,
                ),
              ),
              ...pictureEntries.map(
                (pic) => ItemPicture(
                  photos,
                  pic: pic,
                  requestPrevious: _requestPrevious,
                  requestNext: _requestNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
