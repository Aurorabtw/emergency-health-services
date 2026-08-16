import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/prescription_api_service.dart';
import '../../services/prescription_service.dart';

/// Renders a prescription image from any of the supported sources:
/// - [assetBookingId]: Cloudinary-hosted, fetched via a short-lived signed URL
///   from the Vercel gateway (preferred, current flow).
/// - [documentId]: legacy inline Firestore blob.
/// - [legacyUrl]: pre-migration public URL.
class PrescriptionImage extends StatefulWidget {
  final String? documentId;
  final String? assetBookingId;
  final String? legacyUrl;
  final double? height;

  const PrescriptionImage({
    super.key,
    this.documentId,
    this.assetBookingId,
    this.legacyUrl,
    this.height,
  });

  @override
  State<PrescriptionImage> createState() => _PrescriptionImageState();
}

class _PrescriptionImageState extends State<PrescriptionImage> {
  Future<Uint8List>? _download;
  Future<String>? _assetUrl;

  @override
  void initState() {
    super.initState();
    _setSources();
  }

  @override
  void didUpdateWidget(PrescriptionImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.documentId != oldWidget.documentId ||
        widget.assetBookingId != oldWidget.assetBookingId) {
      _setSources();
    }
  }

  void _setSources() {
    // Prefer the Cloudinary asset. A persisted booking only ever has one source,
    // but a freshly created in-memory model can briefly carry both — pick the
    // asset and create exactly one future so no failing future goes unobserved.
    if (widget.assetBookingId != null) {
      _assetUrl = PrescriptionApiService().viewUrl(widget.assetBookingId!);
      _download = null;
    } else if (widget.documentId != null) {
      _download = PrescriptionService().download(widget.documentId!);
      _assetUrl = null;
    } else {
      _download = null;
      _assetUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_download != null) {
      return FutureBuilder<Uint8List>(
        future: _download,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _Loading(height: widget.height);
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

    if (_assetUrl != null) {
      return FutureBuilder<String>(
        future: _assetUrl,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _Loading(height: widget.height);
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Unavailable(height: widget.height);
          }
          return Image.network(
            snapshot.data!,
            height: widget.height,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _Unavailable(height: widget.height),
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
  final String? assetBookingId;
  final String? legacyUrl;

  const PrescriptionDialogButton({
    super.key,
    this.documentId,
    this.assetBookingId,
    this.legacyUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (documentId == null && assetBookingId == null && legacyUrl == null) {
      return const SizedBox.shrink();
    }
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
                          assetBookingId: assetBookingId,
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

class _Loading extends StatelessWidget {
  final double? height;

  const _Loading({this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? 160,
      child: const Center(child: CircularProgressIndicator()),
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
