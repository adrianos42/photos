import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:rxdart/subjects.dart';
import 'package:desktop/desktop.dart';
import 'package:flutter/foundation.dart';
import 'package:collections/collections.dart';

import 'image_page.dart';
import 'settings.dart';
import 'menu_trailing.dart';

class ItemFolder extends StatefulWidget {
  ItemFolder(this.photos, {required this.dir, Key? key}) : super(key: key);

  final Photos photos;
  final DirectoryEntry dir;

  @override
  _ItemFolderState createState() => _ItemFolderState();
}

class _ItemFolderState extends State<ItemFolder> {
  Future<Uint8List?>? picFuture;
  Size picSize = Size.zero;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dir = widget.dir;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        Navigator.pushNamed(
          context,
          dir.name,
          arguments: dir,
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget picture;

          if (dir.thumbnail != null) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            if (picSize != size) picFuture = null;
            picSize = size;
            
            picFuture ??= widget.photos.image(dir.thumbnail!);
            picture = FutureBuilder<Uint8List?>(
              future: picFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(
                    snapshot.data!,
                    frameBuilder: _frameBuilder,
                    cacheWidth: size.width.toInt() + 200,
                    fit: BoxFit.cover,
                  );
                } else {
                  return Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    color: Color(0x0),
                  );
                }
              },
            );
          } else {
            picture = Container(
              color: colorScheme.overlay2.toColor(),
            );
          }

          return Stack(
            children: [
              Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                padding: EdgeInsets.all(2.0),
                color: Color(0x0),
                child: picture,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 60.0,
                  width: constraints.maxWidth,
                  color: Theme.of(context)
                      .colorScheme
                      .overlay1
                      .withAlpha(0.9)
                      .toColor(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 16.0),
                        child: Icon(
                          Icons.folder,
                          color: colorScheme.shade.toColor(),
                          size: 20.0,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            dir.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ItemPicture extends StatefulWidget {
  ItemPicture(
    this.photos, {
    required this.pic,
    this.requestNext,
    this.requestPrevious,
    Key? key,
  }) : super(key: key);

  final Photos photos;
  final PictureEntry pic;
  final RequestAssetNameCallback? requestPrevious;
  final RequestAssetNameCallback? requestNext;

  @override
  _ItemPictureState createState() => _ItemPictureState();
}

class _ItemPictureState extends State<ItemPicture> {
  Future<Uint8List?>? picFuture;
  Size picSize = Size.zero;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pic = widget.pic;

    return GestureDetector(
      onTap: () async {
        showDialog(
          context: context,
          barrierColor: Theme.of(context).colorScheme.background,
          barrierDismissible: true,
          builder: (context) {
            return ImagePage(
              widget.photos,
              pic: pic,
              requestNext: widget.requestNext,
              requestPrevious: widget.requestPrevious,
            );
          },
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (picSize != size) picFuture = null;
          picSize = size;

          picFuture ??= widget.photos.image(pic.id);

          return Stack(
            alignment: Alignment.topLeft,
            children: [
              Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                //alignment: Alignment.center,
                padding: EdgeInsets.all(2.0),
                color: Color(0x0),
                child: FutureBuilder<Uint8List?>(
                  future: picFuture,
                  //future: ,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return Image.memory(
                            snapshot.data!,
                            frameBuilder: _frameBuilder,
                            cacheWidth: size.width.toInt() + 200,
                            fit: SettingsScope.of(context).viewType ==
                                    ViewType.comfy
                                ? BoxFit.contain
                                : BoxFit.cover,
                          );
                        },
                      );
                    } else {
                      return Container(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        alignment: Alignment.center,
                        color:
                            Theme.of(context).colorScheme.background.toColor(),
                      );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _frameBuilder(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedOpacity(
    child: child,
    opacity: frame == null ? 0 : 1,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );
}





// Size _calculateMinImageSize(Size original, Size target) {
//     var width = original.width;
//     var height = original.height;

//     final minTargetSize =
//         target.width < target.height ? target.width : target.height;

//     if (width > height) {
//       width = minTargetSize;
//       height = (height * minTargetSize) / width;
//     } else {
//       width = (width * minTargetSize) / height;
//       height = minTargetSize;
//     }

//     return Size(width, height);
//   }