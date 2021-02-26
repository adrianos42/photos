import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:desktop/desktop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:collections/collections.dart';
import 'effect.dart';
import 'items.dart';

class PictureEntryCache {
  PictureEntryCache(this.entry);
  final PictureEntry entry;
  Stream<Uint8List>? stream;
}

class DirectoryEntryCache {
  DirectoryEntryCache(this.entry);
  final DirectoryEntry entry;
  Stream<Uint8List>? picStream;
}

class GalleryPage extends StatefulWidget {
  GalleryPage(this.photos, this.directoryEntry, {Key? key}) : super(key: key);

  final Photos photos;
  final DirectoryEntry directoryEntry;

  @override
  _GalleryPageState createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final controller = ScrollController();

  @override
  void initState() {
    super.initState();

    for (var item in widget.directoryEntry.items) {
      switch (item.variant) {
        case Directory.directory:
      }
    }
  }

  List<PictureEntryCache>? _pictureEntries;
  List<PictureEntryCache> get pictureEntries =>
      _pictureEntries ??= widget.directoryEntry.items
          .where((element) => element.variant == Directory.picture)
          .map((e) => PictureEntryCache(e.value as PictureEntry))
          .toList();

  List<DirectoryEntryCache>? _directoryEntries;
  List<DirectoryEntryCache> get directoryEntries =>
      _directoryEntries ??= widget.directoryEntry.items
          .where((element) =>
              element.variant == Directory.directory &&
              element.value.items.length > 0)
          .map((e) => DirectoryEntryCache(e.value as DirectoryEntry))
          .toList();

  Future<PictureEntry?> _requestPrevious(PictureEntry name) async {
    for (var i = 0; i < pictureEntries.length; i += 1) {
      if (name.id == pictureEntries[i].entry.id) {
        final index = i - 1;
        if (index >= 0) {
          return pictureEntries[index].entry;
        }
      }
    }
  }

  Future<PictureEntry?> _requestNext(PictureEntry name) async {
    for (var i = 0; i < pictureEntries.length; i += 1) {
      if (name.id == pictureEntries[i].entry.id) {
        final index = i + 1;
        if (index > 0 && index < pictureEntries.length) {
          return pictureEntries[index].entry;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          childrenDelegate: SliverChildListDelegate.fixed([
            ...directoryEntries
                .map((dir) => ItemFolder(widget.photos, dir.entry)),
            ...pictureEntries.map(
              (pic) => ItemPicture(
                widget.photos,
                pic.entry,
                requestPrevious: _requestPrevious,
                requestNext: _requestNext,
              ),
            )
          ]),
        ),
      ),
    );
  }
}
