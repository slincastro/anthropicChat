import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class UploadedFile {
  final String name;
  final String type;
  final int size;
  final String? base64Data;
  final html.File? htmlFile;

  UploadedFile({
    required this.name,
    required this.type,
    required this.size,
    this.base64Data,
    this.htmlFile,
  });

  bool get isImage => type.startsWith('image/');
  bool get isPdf => type == 'application/pdf';
  bool get isTxt => type == 'text/plain';

  String get sizeDisplay {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get typeDisplay {
    if (isImage) return 'Image';
    if (isPdf) return 'PDF';
    if (isTxt) return 'Text';
    return type;
  }

  IconData get icon {
    if (isImage) return Icons.image;
    if (isPdf) return Icons.picture_as_pdf;
    if (isTxt) return Icons.text_snippet;
    return Icons.insert_drive_file;
  }
}

class ClaudeDropZone extends StatefulWidget {
  final List<UploadedFile> files;
  final Function(List<UploadedFile>) onFilesChanged;
  final bool isStreaming;

  const ClaudeDropZone({
    super.key,
    required this.files,
    required this.onFilesChanged,
    required this.isStreaming,
  });

  @override
  State<ClaudeDropZone> createState() => _ClaudeDropZoneState();
}

class _ClaudeDropZoneState extends State<ClaudeDropZone> {
  final List<String> _allowedTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'application/pdf',
    'text/plain',
  ];

  Future<void> _pickFiles() async {
    if (widget.isStreaming) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'txt'],
      allowMultiple: true,
    );

    if (result != null) {
      final newFiles = <UploadedFile>[];

      for (var file in result.files) {
        if (file.bytes != null) {
          final base64Data = base64Encode(file.bytes!);
          newFiles.add(UploadedFile(
            name: file.name,
            type: file.extension == 'pdf'
                ? 'application/pdf'
                : file.extension == 'txt'
                    ? 'text/plain'
                    : 'image/${file.extension}',
            size: file.size,
            base64Data: base64Data,
          ));
        }
      }

      if (newFiles.isNotEmpty) {
        widget.onFilesChanged([...widget.files, ...newFiles]);
      }
    }
  }

  void _removeFile(int index) {
    if (widget.isStreaming) return;
    final newFiles = List<UploadedFile>.from(widget.files);
    newFiles.removeAt(index);
    widget.onFilesChanged(newFiles);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File list
        if (widget.files.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.files.length,
              itemBuilder: (context, index) {
                final file = widget.files[index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Icon(file.icon, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    file.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${file.typeDisplay} • ${file.sizeDisplay}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.isStreaming)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            color: Colors.white70,
                            onPressed: () => _removeFile(index),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Simplified upload button
        ElevatedButton.icon(
          onPressed: widget.isStreaming ? null : _pickFiles,
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Files'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
