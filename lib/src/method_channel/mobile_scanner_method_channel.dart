import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/src/enums/barcode_format.dart';
import 'package:mobile_scanner/src/enums/mobile_scanner_authorization_state.dart';
import 'package:mobile_scanner/src/enums/mobile_scanner_error_code.dart';
import 'package:mobile_scanner/src/enums/torch_state.dart';
import 'package:mobile_scanner/src/mobile_scanner_exception.dart';
import 'package:mobile_scanner/src/mobile_scanner_platform_interface.dart';
import 'package:mobile_scanner/src/mobile_scanner_view_attributes.dart';
import 'package:mobile_scanner/src/objects/barcode.dart';
import 'package:mobile_scanner/src/objects/barcode_capture.dart';
import 'package:mobile_scanner/src/objects/start_options.dart';

/// An implementation of [MobileScannerPlatform] that uses method channels.
class MethodChannelMobileScanner extends MobileScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );

  /// The event channel that sends back scanned barcode events.
  @visibleForTesting
  final eventChannel = const EventChannel(
    'dev.steenbakker.mobile_scanner/scanner/event',
  );

  Stream<Map<Object?, Object?>>? _eventsStream;

  Stream<Map<Object?, Object?>> get eventsStream {
    _eventsStream ??=
        eventChannel.receiveBroadcastStream().cast<Map<Object?, Object?>>();

    return _eventsStream!;
  }

  int? _textureId;

  /// Parse a [BarcodeCapture] from the given [event].
  BarcodeCapture? _parseBarcode(Map<Object?, Object?>? event) {
    if (event == null) {
      return null;
    }

    final Object? data = event['data'];

    if (data == null || data is! List<Object?>) {
      return null;
    }

    final List<Map<Object?, Object?>> barcodes =
        data.cast<Map<Object?, Object?>>();

    if (Platform.isMacOS) {
      return BarcodeCapture(
        raw: event,
        barcodes: barcodes
            .map(
              (barcode) => Barcode(
                rawValue: barcode['payload'] as String?,
                format: BarcodeFormat.fromRawValue(
                  barcode['symbology'] as int? ?? -1,
                ),
              ),
            )
            .toList(),
      );
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final double? width = event['width'] as double?;
      final double? height = event['height'] as double?;

      return BarcodeCapture(
        raw: data,
        barcodes: barcodes.map(Barcode.fromNative).toList(),
        image: event['image'] as Uint8List?,
        size: width == null || height == null ? Size.zero : Size(width, height),
      );
    }

    throw const MobileScannerException(
      errorCode: MobileScannerErrorCode.genericError,
      errorDetails: MobileScannerErrorDetails(
        message: 'Only Android, iOS and macOS are supported.',
      ),
    );
  }

  /// Request permission to access the camera.
  ///
  /// Throws a [MobileScannerException] if the permission is not granted.
  Future<void> _requestCameraPermission() async {
    final MobileScannerAuthorizationState authorizationState;

    try {
      authorizationState = MobileScannerAuthorizationState.fromRawValue(
        await methodChannel.invokeMethod<int>('state') ?? 0,
      );
    } on PlatformException catch (error) {
      // If the permission state is invalid, that is an error.
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
        errorDetails: MobileScannerErrorDetails(
          code: error.code,
          details: error.details as Object?,
          message: error.message,
        ),
      );
    }

    switch (authorizationState) {
      case MobileScannerAuthorizationState.authorized:
        return; // Already authorized.
      // Android does not have an undetermined authorization state.
      // So if the permission was denied, request it again.
      case MobileScannerAuthorizationState.denied:
      case MobileScannerAuthorizationState.undetermined:
        try {
          final bool granted =
              await methodChannel.invokeMethod<bool>('request') ?? false;

          if (granted) {
            return; // Authorization was granted.
          }

          throw const MobileScannerException(
            errorCode: MobileScannerErrorCode.permissionDenied,
          );
        } on PlatformException catch (error) {
          // If the permission state is invalid, that is an error.
          throw MobileScannerException(
            errorCode: MobileScannerErrorCode.genericError,
            errorDetails: MobileScannerErrorDetails(
              code: error.code,
              details: error.details as Object?,
              message: error.message,
            ),
          );
        }
    }
  }

  @override
  Stream<BarcodeCapture?> get barcodesStream {
    return eventsStream
        .where((event) => event['name'] == 'barcode')
        .map((event) => _parseBarcode(event));
  }

  @override
  Stream<TorchState> get torchStateStream {
    return eventsStream
        .where((event) => event['name'] == 'torchState')
        .map((event) => TorchState.fromRawValue(event['data'] as int? ?? 0));
  }

  @override
  Stream<double> get zoomScaleStateStream {
    return eventsStream
        .where((event) => event['name'] == 'zoomScaleState')
        .map((event) => event['data'] as double? ?? 0.0);
  }

  @override
  Future<BarcodeCapture?> analyzeImage(String path) async {
    final Map<String, Object?>? result =
        await methodChannel.invokeMapMethod<String, Object?>(
      'analyzeImage',
      path,
    );

    return _parseBarcode(result);
  }

  @override
  Widget buildCameraView() {
    if (_textureId == null) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerUninitialized,
        errorDetails: MobileScannerErrorDetails(
          message:
              'The controller was not yet initialized. Call start() before calling buildCameraView().',
        ),
      );
    }

    return Texture(textureId: _textureId!);
  }

  @override
  Future<void> resetZoomScale() async {
    await methodChannel.invokeMethod<void>('resetScale');
  }

  @override
  Future<void> setTorchState(TorchState torchState) async {
    if (torchState == TorchState.unavailable) {
      return;
    }

    await methodChannel.invokeMethod<void>('torch', torchState.rawValue);
  }

  @override
  Future<void> setZoomScale(double zoomScale) async {
    await methodChannel.invokeMethod<void>('setScale', zoomScale);
  }

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    if (_textureId != null) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerAlreadyInitialized,
        errorDetails: MobileScannerErrorDetails(
          message:
              'The scanner was already started. Call stop() before calling start() again.',
        ),
      );
    }

    await _requestCameraPermission();

    Map<String, Object?>? startResult;

    try {
      startResult = await methodChannel.invokeMapMethod<String, Object?>(
        'start',
        startOptions.toMap(),
      );
    } on PlatformException catch (error) {
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
        errorDetails: MobileScannerErrorDetails(
          code: error.code,
          details: error.details as Object?,
          message: error.message,
        ),
      );
    }

    if (startResult == null) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
        errorDetails: MobileScannerErrorDetails(
          message: 'The start method did not return a view configuration.',
        ),
      );
    }

    final int? textureId = startResult['textureId'] as int?;

    if (textureId == null) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
        errorDetails: MobileScannerErrorDetails(
          message: 'The start method did not return a texture id.',
        ),
      );
    }

    _textureId = textureId;

    final bool hasTorch = startResult['torchable'] as bool? ?? false;

    final Map<Object?, Object?>? sizeInfo =
        startResult['size'] as Map<Object?, Object?>?;
    final double? width = sizeInfo?['width'] as double?;
    final double? height = sizeInfo?['height'] as double?;

    final Size size;

    if (width == null || height == null) {
      size = Size.zero;
    } else {
      size = Size(width, height);
    }

    return MobileScannerViewAttributes(hasTorch: hasTorch, size: size);
  }

  @override
  Future<void> stop() async {
    if (_textureId == null) {
      return;
    }

    await methodChannel.invokeMethod<void>('stop');

    _textureId = null;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {
    if (_textureId == null) {
      return;
    }

    List<double>? points;

    if (window != null) {
      points = [window.left, window.top, window.right, window.bottom];
    }

    await methodChannel.invokeMethod<void>(
      'updateScanWindow',
      {'rect': points},
    );
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
