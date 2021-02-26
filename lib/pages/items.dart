import 'dart:typed_data';
import 'dart:ui';

import 'package:desktop/desktop.dart';
import 'package:flutter/foundation.dart';
import 'package:collections/collections.dart';
import 'effect.dart';
import 'image_page.dart';

import 'package:rxdart/subjects.dart';

class ItemFolder extends StatefulWidget {
  ItemFolder(this.photos, this.dir, {Key? key}) : super(key: key);

  Photos photos;
  DirectoryEntry dir;

  @override
  _ItemFolderState createState() => _ItemFolderState();
}

class _ItemFolderState extends State<ItemFolder> {
  final subject = BehaviorSubject<Uint8List>();
  Stream<Uint8List>? picStream;
  int? index;

  @override
  void dispose() {
    subject.close();
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
      child: LayoutBuilder(builder: (context, constraints) {
        Widget picture;

        if (dir.thumbnail != null) {
          if (picStream == null) {
            picStream = widget.photos.image(dir.thumbnail!.id);
            picStream!.listen((event) => subject.add(event));
          }

          picture = StreamBuilder<Uint8List>(
            stream: subject.stream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return AlphaEffect(
                  renders: false,
                  child: Image.memory(
                    snapshot.data!,
                    frameBuilder: _frameBuilder,
                    cacheHeight: constraints.maxHeight > constraints.maxWidth
                        ? constraints.maxHeight.toInt()
                        : null,
                    cacheWidth: constraints.maxWidth > constraints.maxHeight
                        ? constraints.maxWidth.toInt()
                        : null,
                    fit: BoxFit.cover,
                  ),
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
      }),
    );
  }
}

class ItemPicture extends StatefulWidget {
  ItemPicture(
    this.photos,
    this.pic, {
    this.requestNext,
    this.requestPrevious,
    Key? key,
  }) : super(key: key);

  final PictureEntry pic;
  final Photos photos;
  final RequestAssetNameCallback? requestPrevious;
  final RequestAssetNameCallback? requestNext;

  @override
  _ItemPictureState createState() => _ItemPictureState();
}

class _ItemPictureState extends State<ItemPicture> {
  final subject = BehaviorSubject<Uint8List>();
  Stream<Uint8List>? picStream;

  @override
  void dispose() {
    subject.close();
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
              pic,
              requestNext: widget.requestNext,
              requestPrevious: widget.requestPrevious,
            );
          },
        );
      },
      child: LayoutBuilder(builder: (context, constraints) {
        if (picStream == null) {
          picStream = widget.photos.image(pic.id).asBroadcastStream();
          picStream!.listen((event) => subject.add(event));
        }

        return Stack(
          alignment: Alignment.topLeft,
          children: [
            Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              alignment: Alignment.center,
              padding: EdgeInsets.all(2.0),
              color: Color(0x0),
              child: StreamBuilder<Uint8List>(
                stream: subject.stream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return AlphaEffect(
                      renders: pic.mime == 'image/png',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Image.memory(
                            snapshot.data!,
                            frameBuilder: _frameBuilder,
                            cacheHeight: constraints.maxHeight.toInt(),
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                    );
                  } else {
                    return Container(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      color: Color(0x0),
                    );
                  }
                },
              ),
            ),
          ],
        );
      }),
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
