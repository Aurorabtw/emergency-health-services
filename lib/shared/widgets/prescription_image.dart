import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/prescription_service.dart';

class PrescriptionImage extends StatefulWidget {
  final String? documentId;
  final String? legacyUrl;
  final double? height;

  const PrescriptionImage({
    super.key,
    this.documentId,
    this.legacyUrl,
    this.height,
  });

  @override
  State<PrescriptionImage> createState() => _PrescriptionImageState();
}

class _PrescriptionImageState extends State<PrescriptionImage> {
  Future<Uint8List>? _download;

  @override
  void initState() {
    super.initState();
    _setDownload();
  }

  @override
  void didUpdateWidget(PrescriptionImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.documentId != oldWidget.documentId) _setDownload();
  }

  void _setDownload() {
    _download = widget.documentId == null
        ? null
        : PrescriptionService().download(widget.documentId!);
  }

  @override
  Widget build(BuildContext context) {
    if (_download != null) {
      return FutureBuilder<Uint8List>(
        future: _download,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              height: widget.height ?? 160,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Unavailable(height: widget.height);
          }
          return Image.memory(
            snapshot.data!,
            height: widget.height,
            fit: BoxFit.contain,
          );
        },
      );
    }

    if (widget.legacyUrl != null) {
      return Image.network(
        widget.legacyUrl!,
        height: widget.height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _Unavailable(height: widget.height),
      );
    }

    return _Unavailable(height: widget.height);
  }
}

class PrescriptionDialogButton extends StatelessWidget {
  final String? documentId;
  final String? legacyUrl;

  const PrescriptionDialogButton({
    super.key,
    this.documentId,
    this.legacyUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (documentId == null && legacyUrl == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton.icon(
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 600, maxWidth: 650),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      title: const Text('Prescription'),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: PrescriptionImage(
                          documentId: documentId,
                          legacyUrl: legacyUrl,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        icon: const Icon(Icons.image),
        label: const Text('View Prescription'),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  final double? height;

  const _Unavailable({this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? 100,
      child: const Center(child: Text('Image unavailable')),
    );
  }
}
