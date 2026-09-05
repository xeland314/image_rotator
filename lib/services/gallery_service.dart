import 'dart:io';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Guarda imágenes en galería con fallback para Linux (donde `gal_linux` no existe).
/// En Linux copia a `getDownloadsDirectory()` o `getApplicationDocumentsDirectory()`.
class GalleryService {
  static Future<String> saveImage(String imagePath) async {
    if (Platform.isLinux) {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, p.basename(imagePath));
      await File(imagePath).copy(dest);
      return dest;
    }
    try {
      await Gal.putImage(imagePath);
      return imagePath;
    } on MissingPluginException {
      // Fallback si el plugin no está registrado en la plataforma
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, p.basename(imagePath));
      await File(imagePath).copy(dest);
      return dest;
    }
  }

  static Future<bool> hasAccess() async {
    if (Platform.isLinux) return true;
    try {
      return await Gal.hasAccess();
    } on MissingPluginException {
      return true;
    }
  }

  static Future<bool> requestAccess() async {
    if (Platform.isLinux) return true;
    try {
      return await Gal.requestAccess();
    } on MissingPluginException {
      return true;
    }
  }
}
