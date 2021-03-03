#!/usr/bin/bash

idl client --path=plugins/collections
flutter build linux --verbose --release
rm -rf ~/opt/photos
mkdir -p ~/opt/photos
cp -r build/linux/x64/release/bundle/* ~/opt/photos/
cp assets/photo_library-black-90dp.png ~/opt/photos/icon.png
cp linux_package/photos.desktop ~/.local/share/applications/photos.desktop
echo "" >> ~/.local/share/applications/photos.desktop
echo "Exec=$HOME/opt/photos/photos" >> ~/.local/share/applications/photos.desktop
echo "Icon=$HOME/opt/photos/icon.png" >> ~/.local/share/applications/photos.desktop