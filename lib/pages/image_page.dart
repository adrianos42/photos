import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:desktop/desktop.dart';
import 'package:flutter/foundation.dart';
import 'package:collections/collections.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/subjects.dart';

typedef RequestAssetNameCallback = Future<PictureEntry?> Function(PictureEntry);

class ImagePage extends StatefulWidget {
  ImagePage(
    this.photos, {
    required this.pic,
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

class _ImagePageState extends State<ImagePage> with TickerProviderStateMixin {
  Timer? fadeoutTimer;
  bool firstBuild = true;
  bool offstage = false;
  bool menuFocus = false;

  void _startFadeoutTimer() {
    fadeoutTimer?.cancel();

    setState(() {
      offstage = false;
      fadeoutTimer = Timer(Duration(milliseconds: 2000), () {
        setState(() => fadeoutTimer = null);
      });
    });
  }

  PictureEntry? replacePic;

  late Map<Type, Action<Intent>> _actionMap;
  late Map<LogicalKeySet, Intent> _shortcutMap;

  Future<void> _requestPrevious() async {
    final replace = await widget.requestPrevious?.call(pictureEntry);
    if (replace != null) {
      setState(() {
        picFuture = null;
        replacePic = replace;
      });
    }
  }

  Future<void> _requestNext() async {
    final replace = await widget.requestNext?.call(pictureEntry);
    if (replace != null) {
      setState(() {
        picFuture = null;
        replacePic = replace;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _actionMap = <Type, Action<Intent>>{
      ScrollIntent: CallbackAction<ScrollIntent>(onInvoke: (action) async {
        switch (action.direction) {
          case AxisDirection.left:
            if (widget.requestPrevious != null) await _requestPrevious();
            break;
          case AxisDirection.right:
            if (widget.requestNext != null) await _requestNext();
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

  Future<Uint8List?>? picFuture;

  @override
  void dispose() {
    fadeoutTimer?.cancel();
    fadeoutTimer = null;
    super.dispose();
  }

  PictureEntry get pictureEntry => replacePic ?? widget.pic;

  bool _canRequestPrevious = false;
  bool _canRequestNext = false;

  @override
  Widget build(BuildContext context) {
    if (firstBuild) {
      _startFadeoutTimer();
      firstBuild = false;
    }

    widget.requestPrevious?.call(pictureEntry).then((value) {
      setState(() => _canRequestPrevious = value != null);
    });

    widget.requestNext?.call(pictureEntry).then((value) {
      setState(() => _canRequestNext = value != null);
    });

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    picFuture ??= widget.photos.image(pictureEntry.id);

    Widget result = MouseRegion(
      onHover: (_) => _startFadeoutTimer(),
      child: Stack(
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  return Container(
                    height: constraints.maxHeight,
                    alignment: Alignment.center,
                    color: Color(0x0),
                    child: FutureBuilder<Uint8List?>(
                      future: picFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.contain,
                            cacheHeight: constraints.maxHeight.toInt(),
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
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(pictureEntry.name),
                                ),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16.0),
                                          child: Builder(
                                            builder: (context) {
                                              return Row(
                                                children: [
                                                  if (widget.requestPrevious !=
                                                      null)
                                                    IconButton(
                                                      Icons.navigate_before,
                                                      onPressed:
                                                          _canRequestPrevious
                                                              ? _requestPrevious
                                                              : null,
                                                      tooltip: 'Previous',
                                                    ),
                                                  if (widget.requestNext !=
                                                      null)
                                                    IconButton(
                                                      Icons.navigate_next,
                                                      onPressed: _canRequestNext
                                                          ? _requestNext
                                                          : null,
                                                      tooltip: 'Next',
                                                    ),
                                                ],
                                              );
                                            },
                                          )),
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
                    onEnd: () => setState(
                        () => offstage = fadeoutTimer == null && !menuFocus),
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
