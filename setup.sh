#!/usr/bin/env bash
# Запуск: ./setup.sh   (нужен установленный Flutter SDK >= 3.19)
set -e
flutter create --org com.musichub --project-name musichub --platforms=android .
cp android_patch/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
flutter pub get
dart run flutter_launcher_icons
echo "Готово. Запуск: flutter run   |   Сборка: flutter build apk --release"
