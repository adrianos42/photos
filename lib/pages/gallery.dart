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

class PictureEntryCache {
  PictureEntryCache(this.entry);
  final PictureEntry entry;
  Future<Uint8List?>? future;
}

class DirectoryEntryCache {
  DirectoryEntryCache(this.entry);
  final DirectoryEntry entry;
  Future<Uint8List?>? picFuture;
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

  PictureEntry? _requestPrevious(PictureEntry name) {
    for (var i = 0; i < pictureEntries.length; i += 1) {
      if (name.id == pictureEntries[i].entry.id) {
        final index = i - 1;
        if (index >= 0) {
          return pictureEntries[index].entry;
        } else {
          return null;
        }
      }
    }
    return null;
  }

  PictureEntry? _requestNext(PictureEntry name) {
    for (var i = 0; i < pictureEntries.length; i += 1) {
      if (name.id == pictureEntries[i].entry.id) {
        final index = i + 1;
        if (index > 0 && index < pictureEntries.length) {
          return pictureEntries[index].entry;
        } else {
          return null;
        }
      }
    }
    return null;
    // final index = pictureEntries.lastIndexOf(name) + 1;

    // if (index > 0 && index < pictureEntries.length) {
    //   return pictureEntries[index];
    // } else {
    //   return null;
    // }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(top: 16.0),
      child: Scrollbar(
        controller: controller,
        child: GridView.custom(
          controller: controller,
          padding: const EdgeInsets.all(4.0),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisSpacing: 2.0,
            crossAxisSpacing: 2.0,
            childAspectRatio: 1.2,
          ),
          childrenDelegate: SliverChildListDelegate.fixed([
            ...directoryEntries.map((dir) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    Navigator.pushNamed(
                      context,
                      dir.entry.name,
                      arguments: dir.entry,
                    );
                  },
                  child: LayoutBuilder(builder: (context, constraints) {
                    final picList = dir.entry.items
                        .where((e) => Directory.picture == e.variant)
                        .toList();

                    Widget picture;
                    if (picList.length > 0) {
                      final index = picList.length > 1
                          ? Random.secure().nextInt(picList.length - 1)
                          : 0;
                      final picEntry = picList[index].value as PictureEntry;
                      dir.picFuture ??= widget.photos.image(picEntry.id);
                      picture = FutureBuilder<Uint8List?>(
                        future: dir.picFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return AlphaEffect(
                              renders: false,
                              child: Image.memory(
                                snapshot.data!,
                                //frameBuilder: _frameBuilder,
                                cacheWidth: constraints.maxWidth.toInt(),
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
                                      dir.entry.name,
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
                )),
            ...pictureEntries.map(
              (pic) => GestureDetector(
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierColor: Theme.of(context).colorScheme.background,
                    barrierDismissible: true,
                    builder: (context) {
                      return _ImagePage(
                        widget.photos,
                        pic.entry,
                        requestNext: _requestNext,
                        requestPrevious: _requestPrevious,
                      );
                    },
                  );
                },
                child: LayoutBuilder(builder: (context, constraints) {
                  pic.future ??= widget.photos.image(pic.entry.id);

                  return Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      Container(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(2.0),
                        color: Color(0x0),
                        child: FutureBuilder<Uint8List?>(
                          future: pic.future!,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return AlphaEffect(
                                renders: pic.entry.mime == 'image/png',
                                child: Image.memory(
                                  snapshot.data!,
                                  //frameBuilder: _frameBuilder,
                                  cacheWidth: constraints.maxWidth.toInt(),
                                  fit: BoxFit.contain,
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
                      // Align(
                      //   alignment: Alignment.bottomCenter,
                      //   child: Container(
                      //     height: 60.0,
                      //     width: constraints.maxWidth,
                      //     color: Theme.of(context)
                      //         .colorScheme
                      //         .overlay1
                      //         .withAlpha(0.9)
                      //         .toColor(),
                      //     child: Row(
                      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //       children: [
                      //         Padding(
                      //           padding: EdgeInsets.only(left: 16.0),
                      //           child: Icon(
                      //             Icons.image,
                      //             color: colorScheme.shade.toColor(),
                      //             size: 20.0,
                      //           ),
                      //         ),
                      //         Expanded(
                      //           child: Padding(
                      //             padding: EdgeInsets.all(16.0),
                      //             child: Text(
                      //               pic.entry.name,
                      //               overflow: TextOverflow.ellipsis,
                      //             ),
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                    ],
                  );
                }),
              ),
            )
          ]),
        ),
      ),
    );
  }
}

typedef RequestAssetNameCallback = PictureEntry? Function(PictureEntry);

class _ImagePage extends StatefulWidget {
  _ImagePage(
    this.photos,
    this.pic, {
    this.requestNext,
    this.requestPrevious,
    Key? key,
  }) : super(key: key);

  final Photos photos;
  final PictureEntry pic;

  final RequestAssetNameCallback? requestNext;
  final RequestAssetNameCallback? requestPrevious;

  @override
  _ImagePageState createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> with TickerProviderStateMixin {
  Timer? fadeoutTimer;
  bool firstBuild = true;
  bool offstage = false;
  bool menuFocus = false;

  void _startFadeoutTimer() {
    fadeoutTimer?.cancel();

    setState(() {
      offstage = false;
      fadeoutTimer = Timer(Duration(milliseconds: 1500), () {
        setState(() => fadeoutTimer = null);
      });
    });
  }

  PictureEntry? replacePic;

  late Map<Type, Action<Intent>> _actionMap;
  late Map<LogicalKeySet, Intent> _shortcutMap;

  void _requestPrevious() {
    final canRequestPrevious =
        widget.requestPrevious?.call(pictureEntry) != null;
    if (canRequestPrevious) {
      _picture = null;
      setState(
          () => replacePic = widget.requestPrevious!(replacePic ?? widget.pic));
    }
  }

  void _requestNext() {
    final canRequestNext = widget.requestNext?.call(pictureEntry) != null;
    if (canRequestNext) {
      _picture = null;
      setState(
          () => replacePic = widget.requestNext!(replacePic ?? widget.pic));
    }
  }

  @override
  void initState() {
    super.initState();

    _actionMap = <Type, Action<Intent>>{
      ScrollIntent: CallbackAction<ScrollIntent>(onInvoke: (action) {
        switch (action.direction) {
          case AxisDirection.left:
            if (widget.requestPrevious != null) _requestPrevious();
            break;
          case AxisDirection.right:
            if (widget.requestNext != null) _requestNext();
            break;
          default:
        }
      }),
    };

    _shortcutMap = <LogicalKeySet, Intent>{
      LogicalKeySet(LogicalKeyboardKey.arrowLeft):
          const ScrollIntent(direction: AxisDirection.left),
      LogicalKeySet(LogicalKeyboardKey.arrowRight):
          const ScrollIntent(direction: AxisDirection.right),
    };
  }

  @override
  void dispose() {
    fadeoutTimer?.cancel();
    fadeoutTimer = null;
    super.dispose();
  }

  Future<Uint8List?>? _picture;
  Future<Uint8List?> get picture {
    _picture ??= widget.photos.image(pictureEntry.id);
    return _picture!;
  }

  PictureEntry get pictureEntry => replacePic ?? widget.pic;

  @override
  Widget build(BuildContext context) {
    if (firstBuild) {
      _startFadeoutTimer();
      firstBuild = false;
    }

    final canRequestPrevious =
        widget.requestPrevious?.call(pictureEntry) != null;
    final canRequestNext = widget.requestNext?.call(pictureEntry) != null;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    Widget result = MouseRegion(
      onHover: (_) => _startFadeoutTimer(),
      child: Stack(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            return Container(
              height: constraints.maxHeight,
              color: Color(0x0),
              alignment: Alignment.center,
              child: FutureBuilder<Uint8List?>(
                future: picture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return AlphaEffect(
                      renders: pictureEntry.mime == 'image/png',
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        cacheHeight: constraints.maxHeight.toInt(),
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
            );
          }),
          Offstage(
            offstage: offstage,
            child: AnimatedOpacity(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  color: colorScheme.overlay2.toColor(),
                  height: 60.0,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => menuFocus = true),
                    onExit: (_) => setState(() => menuFocus = false),
                    child: ButtonTheme.merge(
                      data: ButtonThemeData(
                        color: textTheme.textLow,
                        hoverColor: textTheme.textMedium,
                        highlightColor: textTheme.textHigh,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(pictureEntry.name),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      if (widget.requestPrevious != null)
                                        IconButton(
                                          Icons.navigate_before,
                                          onPressed: canRequestPrevious
                                              ? _requestPrevious
                                              : null,
                                          tooltip: 'Previous',
                                        ),
                                      if (widget.requestNext != null)
                                        IconButton(
                                          Icons.navigate_next,
                                          onPressed: canRequestNext
                                              ? _requestNext
                                              : null,
                                          tooltip: 'Next',
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  Icons.close,
                                  onPressed: () => Navigator.pop(context),
                                  tooltip: 'Close',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              opacity: fadeoutTimer == null && !menuFocus ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: fadeoutTimer == null && !menuFocus
                  ? Curves.easeOutSine
                  : Curves.easeInSine,
              onEnd: () =>
                  setState(() => offstage = fadeoutTimer == null && !menuFocus),
              //curve: Curves.easeOutSine,
            ),
          ),
        ],
      ),
    );

    return FocusableActionDetector(
      child: result,
      autofocus: true,
      actions: _actionMap,
      shortcuts: _shortcutMap,
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
