import 'dart:io';
import 'dart:ui';
import 'package:desktop/desktop.dart';
import 'package:flutter/foundation.dart';
import 'package:collections/collections.dart';

import 'pages/gallery.dart';

void main() => runApp(DocApp());

class DocApp extends StatefulWidget {
  DocApp({Key? key}) : super(key: key);

  @override
  _DocAppState createState() => _DocAppState();
}

class _DocAppState extends State<DocApp> {
  ThemeData _themeData = ThemeData(brightness: Brightness.dark);
  ThemeData get themeData =>
      ThemeData(brightness: _themeData.brightness, primaryColor: primaryColor);

  PrimaryColor primaryColor = PrimaryColors.dodgerBlue;

  late Photos photos;

  Stream<DirectoryEntry>? directoryEntryStream;

  @override
  void initState() {
    super.initState();
    photos = Photos();
  }

  @override
  void dispose() {
    photos.dispose();
    super.dispose();
  }

  int countPictures(DirectoryEntry entry) {
    var count = 0;

    for (var item in entry.items) {
      switch (item.variant) {
        case Directory.directory:
          count += countPictures(item.value as DirectoryEntry);
          break;
        case Directory.picture:
          count += 1;
          break;
        default:
          break;
      }
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    directoryEntryStream ??= photos.directory();

    return DesktopApp(
      theme: themeData,
      home: Builder(
        builder: (context) => Container(
          alignment: Alignment.center,
          padding: EdgeInsets.only(top: 8.0),
          child: StreamBuilder<DirectoryEntry>(
            stream: directoryEntryStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final directoryEntry = snapshot.data!;
                final picsNumber = countPictures(directoryEntry);
                return picsNumber > 0
                    ? Breadcrumb(
                        initialRoute: 'Pictures/',
                        leading: Padding(
                          padding: EdgeInsets.only(left: 16.0),
                          child: Icon(
                            Icons.collections,
                            color:
                                Theme.of(context).colorScheme.primary.toColor(),
                            size: 22.0,
                          ),
                        ),
                        trailing: Row(
                          children: [
                            ThemeToggle(
                              onPressed: () => setState(() =>
                                  _themeData = Theme.invertedThemeOf(context)),
                            ),
                          ],
                        ),
                        routeBuilder: (context, settings) {
                          switch (settings.name) {
                            case 'Pictures/':
                              return DesktopPageRoute(
                                fullscreenDialog: false,
                                builder: (context) =>
                                    GalleryPage(photos, directoryEntry),
                                settings: RouteSettings(name: settings.name),
                              );
                            default:
                              final dirEntry =
                                  settings.arguments as DirectoryEntry;
                              return DesktopPageRoute(
                                fullscreenDialog: false,
                                builder: (context) =>
                                    GalleryPage(photos, dirEntry),
                                settings: RouteSettings(name: dirEntry.name),
                              );
                          }
                        },
                      )
                    : Container(
                        alignment: Alignment.center,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/photo_library-black-90dp.png',
                              width: 100.0,
                            ),
                            Text('Pictures folder is empty',
                                style: Theme.of(context).textTheme.title),
                          ],
                        ),
                      );
              }

              return Container(
                alignment: Alignment.center,
                child: CircularProgressIndicator(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ThemeToggle extends StatefulWidget {
  ThemeToggle({
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  final VoidCallback onPressed;

  @override
  _ThemeToggleState createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<ThemeToggle> {
  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final iconForeground = themeData.textTheme.textHigh;
    switch (themeData.brightness) {
      case Brightness.dark:
        return Button(
          onPressed: widget.onPressed,
          body: Icon(
            IconData(0x61, fontFamily: 'mode'),
            color: iconForeground.toColor(),
          ),
        );
      case Brightness.light:
        return Button(
          onPressed: widget.onPressed,
          body: Icon(
            IconData(0x62, fontFamily: 'mode'),
            color: iconForeground.toColor(),
          ),
        );
    }
  }
}
