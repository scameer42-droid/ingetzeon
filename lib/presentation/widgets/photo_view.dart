import 'dart:io';

import 'package:flutter/material.dart';

/// Foto kecil membulat; ketuk untuk melihat layar penuh.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb(this.path, {super.key, this.height = 180, this.radius = 18, this.width = double.infinity});
  final String path;
  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => openPhoto(context, path),
      child: Hero(
        tag: path,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(file, height: height, width: width, fit: BoxFit.cover, cacheWidth: 900),
        ),
      ),
    );
  }
}

void openPhoto(BuildContext context, String path) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (c) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: Hero(
          tag: path,
          child: InteractiveViewer(maxScale: 5, child: Image.file(File(path))),
        ),
      ),
    ),
  ));
}
