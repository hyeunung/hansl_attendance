import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionStatementSummary {
  final String id;
  final String imageUrl;
  final String? fileName;
  final String status;
  final DateTime uploadedAt;
  final String? uploaderName;
  final DateTime? statementDate;
  final String? vendorName;
  final num? grandTotal;
  final String? confirmedByName;

  TransactionStatementSummary({
    required this.id,
    required this.imageUrl,
    required this.fileName,
    required this.status,
    required this.uploadedAt,
    required this.uploaderName,
    required this.statementDate,
    required this.vendorName,
    required this.grandTotal,
    required this.confirmedByName,
  });

  factory TransactionStatementSummary.fromMap(Map<String, dynamic> data) {
    final statementDateRaw = data['statement_date'];
    return TransactionStatementSummary(
      id: data['id'] as String,
      imageUrl: data['image_url'] as String,
      fileName: data['file_name'] as String?,
      status: (data['status'] as String?) ?? 'pending',
      uploadedAt: DateTime.parse(data['uploaded_at'] as String).toLocal(),
      uploaderName: data['uploaded_by_name'] as String?,
      statementDate: statementDateRaw == null
          ? null
          : DateTime.parse(statementDateRaw as String).toLocal(),
      vendorName: data['vendor_name'] as String?,
      grandTotal: data['grand_total'] as num?,
      confirmedByName: data['confirmed_by_name'] as String?,
    );
  }
}

class TransactionStatementUploadResult {
  final String statementId;
  final String imageUrl;

  const TransactionStatementUploadResult({
    required this.statementId,
    required this.imageUrl,
  });
}

class TransactionStatementService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final ImagePicker _imagePicker = ImagePicker();

  static Future<XFile?> pickImage(ImageSource source) {
    return _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
  }

  static Future<TransactionStatementUploadResult> uploadStatement({
    required XFile imageFile,
    required String uploaderName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final fileExtension = path.extension(imageFile.path).toLowerCase();
    final fileName = _generateFileName(fileExtension);
    final storagePath = 'Transaction Statement/$fileName';

    final bytes = await imageFile.readAsBytes();
    await _supabase.storage.from('receipt-images').uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: _getContentType(fileExtension),
        upsert: false,
      ),
    );

    final imageUrl = _supabase.storage
        .from('receipt-images')
        .getPublicUrl(storagePath);

    final insertResponse = await _supabase
        .from('transaction_statements')
        .insert({
          'image_url': imageUrl,
          'file_name': imageFile.name.isNotEmpty ? imageFile.name : fileName,
          'uploaded_by': user.id,
          'uploaded_by_name': uploaderName,
          'status': 'processing',
          'uploaded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    final statementId = insertResponse['id'] as String;

    Future<void>(() async {
      await _invokeOcr(
        statementId: statementId,
        imageUrl: imageUrl,
      );
    });

    return TransactionStatementUploadResult(
      statementId: statementId,
      imageUrl: imageUrl,
    );
  }

  static Future<List<TransactionStatementSummary>> fetchStatements() async {
    final response = await _supabase
        .from('transaction_statements')
        .select(
          'id, image_url, file_name, status, uploaded_at, uploaded_by_name, '
          'statement_date, vendor_name, grand_total, confirmed_by_name',
        )
        .order('uploaded_at', ascending: false);

    final data = List<Map<String, dynamic>>.from(response);
    return data.map(TransactionStatementSummary.fromMap).toList();
  }

  static Future<String?> _invokeOcr({
    required String statementId,
    required String imageUrl,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ocr-transaction-statement',
        body: {
          'statementId': statementId,
          'imageUrl': imageUrl,
        },
      );

      final status = response.status;
      if (status != null && status != 200) {
        return 'OCR 호출 실패 (HTTP $status)';
      }

      final data = response.data;
      if (data is Map && data['success'] == false) {
        return (data['error'] as String?) ?? 'OCR 처리 실패';
      }
    } catch (e) {
      return 'OCR 호출 중 오류가 발생했습니다.';
    }

    return null;
  }

  static String _generateFileName(String extension) {
    final rand = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = List.generate(6, (_) => rand.nextInt(36))
        .map((n) => n.toRadixString(36))
        .join();
    final safeExtension = extension.isNotEmpty ? extension : '.jpg';
    return 'ts_$timestamp\_$randomSuffix$safeExtension';
  }

  static String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.heic':
        return 'image/heic';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
