import 'dart:io';
import 'package:flutter/material.dart';
import 'photo_view_screen.dart';
import 'video_view_screen.dart';

class GalleryScreen extends StatefulWidget {
  final Directory directory;

  const GalleryScreen({super.key, required this.directory});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _mediaFiles = [];

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  void _loadMedia() {
    final files = widget.directory
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith('.jpg') || file.path.endsWith('.mp4'),
        )
        .toList();

    // Sort by newest first
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );

    setState(() => _mediaFiles = files);
  }

  void _openMedia(File file) {
    if (file.path.endsWith('.mp4')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoViewScreen(videoPath: file.path),
        ),
      ).then((_) => _loadMedia()); // Reload after returning
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoViewScreen(imagePath: file.path),
        ),
      ).then((_) => _loadMedia()); // Reload after returning
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Gallery'),
      ),
      body: _mediaFiles.isEmpty
          ? const Center(
              child: Text(
                'No media files',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _mediaFiles.length,
              itemBuilder: (context, index) {
                final file = _mediaFiles[index];
                final isVideo = file.path.endsWith('.mp4');

                return GestureDetector(
                  onTap: () => _openMedia(file),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white30,
                          ),
                        ),
                      ),
                      if (isVideo)
                        const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
