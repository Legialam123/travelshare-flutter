import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AttachmentPicker extends StatefulWidget {
  final Function(List<File>) onFilesPicked;
  const AttachmentPicker({Key? key, required this.onFilesPicked})
      : super(key: key);

  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends State<AttachmentPicker> {
  final List<File> _files = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _files.add(File(pickedFile.path));
      });
      widget.onFilesPicked(_files);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: _pickImage,
          child: const Text('Chọn file đính kèm'),
        ),
        Wrap(
          children: _files
              .map((file) => Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.file(file,
                        width: 60, height: 60, fit: BoxFit.cover),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
