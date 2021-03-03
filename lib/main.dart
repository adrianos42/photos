import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:desktop/desktop.dart';
import 'package:flutter/foundation.dart';
import 'package:collections/collections.dart';
import 'package:photos/pages/settings.dart';
import 'package:rxdart/subjects.dart';

import 'pages/gallery.dart';
import 'pages/menu_trailing.dart';

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

  @override
  void initState() {
    super.initState();
    photos = Photos();
  }

  @override
  void dispose() {
    directoryEntryStream?.cancel();
    directoryEntrySubject.close();
    photos.dispose();
    super.dispose();
  }

  StreamSubscription<PicturesDirectory>? directoryEntryStream;
  final directoryEntrySubject = BehaviorSubject<PicturesDirectory>();

  ViewType _viewType = ViewType.compact;

  Widget _createHome() {
    if (directoryEntryStream == null) {
      directoryEntryStream = photos
          .picturesDirectory()
          .listen((event) => directoryEntrySubject.add(event));
    }

    return StreamBuilder<PicturesDirectory>(
        stream: directoryEntrySubject.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final picturesDirectory = snapshot.data!;
            if (picturesDirectory.nPictures > 0) {
              return SettingsScope(
                viewType: _viewType,
                child: Breadcrumb(
                  initialRoute: 'Pictures/',
                  leading: Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Icon(
                      Icons.collections,
                      color: Theme.of(context).colorScheme.primary.toColor(),
                      size: 22.0,
                    ),
                  ),
                  trailing: Builder(
                    builder: (context) => TrailingMenuPage(
                      onViewTypeChanged: (viewType) =>
                          setState(() => _viewType = viewType),
                      onThemeChanged: () => setState(
                          () => _themeData = Theme.invertedThemeOf(context)),
                    ),
                  ),
                  routeBuilder: (context, settings) {
                    switch (settings.name) {
                      case 'Pictures/':
                        return DesktopPageRoute(
                          fullscreenDialog: false,
                          builder: (context) =>
                              GalleryPage(photos, picturesDirectory.directory),
                          settings: RouteSettings(name: settings.name),
                        );
                      default:
                        final dirEntry = settings.arguments as DirectoryEntry;
                        return DesktopPageRoute(
                          fullscreenDialog: false,
                          builder: (context) => GalleryPage(photos, dirEntry),
                          settings: RouteSettings(name: dirEntry.name),
                        );
                    }
                  },
                ),
              );
            } else {
              return Container(
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
          } else {
            return Container(
              alignment: Alignment.center,
              child: CircularProgressIndicator(),
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopApp(
      theme: themeData,
      home: Builder(
        builder: (context) => Container(
          alignment: Alignment.center,
          padding: EdgeInsets.only(top: 8.0),
          child: _createHome(),
        ),
      ),
    );
  }
}
