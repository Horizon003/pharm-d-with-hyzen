import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/photo_crop_screen.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../errors/app_error.dart';

class MediaUpload {
  static const channel = MethodChannel('com.hyzen.pharmd/csv_files');
  static Future<String?> pickAndUpload({BuildContext? context}) async {
    final value = await channel.invokeMapMethod<String, dynamic>('pickImage');
    if (value == null) return null;
    var bytes = value['bytes'] as Uint8List;
    if (context != null) {
      if (!context.mounted) return null;
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => PhotoCropScreen(bytes: bytes)),
      );
      if (cropped == null) return null;
      bytes = cropped;
    }
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('https://api.cloudinary.com/v1_1/djlt2chgd/image/upload'),
          )
          ..fields['upload_preset'] = 'pharmawhisper_upload'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: context == null ? 'hyzen_photo.jpg' : 'hyzen_photo.png',
            ),
          );
    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final body = await response.stream.bytesToString().timeout(
        const Duration(seconds: 45),
      );
      if (response.statusCode >= 300) {
        throw FriendlyException('Photo upload failed. Please try again.');
      }
      final url = (jsonDecode(body) as Map)['secure_url'];
      if (url is! String || Uri.tryParse(url)?.host != 'res.cloudinary.com') {
        throw FriendlyException('Photo could not be uploaded.');
      }
      return url;
    } finally {
      client.close();
    }
  }

  static Future<bool> exportText(
    String name,
    String text, {
    String mime = 'text/plain',
  }) async =>
      await channel.invokeMethod<bool>('saveFile', {
        'name': name,
        'text': text,
        'mime': mime,
      }) ??
      false;
  static Future<bool> exportPdf(String path, String name) async =>
      exportDocument(path, name, 'application/pdf');

  static Future<bool> exportDocument(
    String path,
    String name,
    String mime,
  ) async =>
      await channel.invokeMethod<bool>('exportFile', {
        'name': name,
        'path': path,
        'mime': mime,
      }) ??
      false;

  static Future<bool> shareDocument(
    String path,
    String name,
    String mime,
  ) async =>
      await channel.invokeMethod<bool>('shareFile', {
        'name': name,
        'path': path,
        'mime': mime,
      }) ??
      false;
}
