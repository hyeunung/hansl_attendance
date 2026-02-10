import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionStatementSummary {
  final String id;
  final String imageUrl;
  final String? fileName;
  final String status;
  final String statementMode;
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
    required this.statementMode,
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
      statementMode: (data['statement_mode'] as String?) ?? 'default',
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

  /// 일반 거래명세서 업로드 (웹앱 uploadStatement와 동일)
  /// status: 'queued', 큐 시스템에서 OCR 자동 처리
  static Future<TransactionStatementUploadResult> uploadStatement({
    required XFile imageFile,
    required String uploaderName,
    required String poScope,
    required DateTime actualReceiptDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final imageUrl = await _uploadImageToStorage(imageFile);
    final dateStr = DateFormat('yyyy-MM-dd').format(actualReceiptDate);

    final insertResponse = await _supabase
        .from('transaction_statements')
        .insert({
          'image_url': imageUrl,
          'file_name': imageFile.name.isNotEmpty
              ? imageFile.name
              : imageUrl.split('/').last,
          'uploaded_by': user.id,
          'uploaded_by_name': uploaderName,
          'status': 'queued',
          'queued_at': DateTime.now().toUtc().toIso8601String(),
          'po_scope': poScope,
          'extracted_data': {'actual_received_date': dateStr},
        })
        .select()
        .single();

    return TransactionStatementUploadResult(
      statementId: insertResponse['id'] as String,
      imageUrl: imageUrl,
    );
  }

  /// 입고수량 업로드 (웹앱 uploadReceiptQuantity와 동일)
  /// status: 'queued', statement_mode: 'receipt'
  /// OCR 트리거는 화면 레이어에서 extractStatementData로 처리 (웹앱 패턴)
  static Future<TransactionStatementUploadResult> uploadReceiptQuantity({
    required XFile imageFile,
    required String uploaderName,
    required String poScope,
    required DateTime actualReceiptDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final imageUrl = await _uploadImageToStorage(imageFile);
    final dateStr = DateFormat('yyyy-MM-dd').format(actualReceiptDate);

    final insertResponse = await _supabase
        .from('transaction_statements')
        .insert({
          'image_url': imageUrl,
          'file_name': imageFile.name.isNotEmpty
              ? imageFile.name
              : imageUrl.split('/').last,
          'uploaded_by': user.id,
          'uploaded_by_name': uploaderName,
          'status': 'queued',
          'queued_at': DateTime.now().toUtc().toIso8601String(),
          'statement_mode': 'receipt',
          'po_scope': poScope,
          'extracted_data': {'actual_received_date': dateStr},
        })
        .select()
        .single();

    return TransactionStatementUploadResult(
      statementId: insertResponse['id'] as String,
      imageUrl: imageUrl,
    );
  }

  /// 월말결제 거래명세서 업로드 (웹앱 uploadMonthlyStatement와 동일)
  /// status: 'processing', statement_mode: 'monthly'
  /// 업로드 후 parse-monthly-statement Edge Function 호출
  static Future<TransactionStatementUploadResult> uploadMonthlyStatement({
    required XFile imageFile,
    required String uploaderName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final imageUrl = await _uploadImageToStorage(imageFile);

    final insertResponse = await _supabase
        .from('transaction_statements')
        .insert({
          'image_url': imageUrl,
          'file_name': imageFile.name.isNotEmpty
              ? imageFile.name
              : imageUrl.split('/').last,
          'uploaded_by': user.id,
          'uploaded_by_name': uploaderName,
          'status': 'processing',
          'processing_started_at': DateTime.now().toUtc().toIso8601String(),
          'statement_mode': 'monthly',
          'extracted_data': {'file_type': 'image'},
        })
        .select()
        .single();

    final statementId = insertResponse['id'] as String;

    // 월말결제 전용 Edge Function 비동기 호출
    Future<void>(() async {
      try {
        await _supabase.functions.invoke(
          'parse-monthly-statement',
          body: {
            'statementId': statementId,
            'fileUrl': imageUrl,
            'fileType': 'image',
          },
        );
      } catch (_) {}
    });

    return TransactionStatementUploadResult(
      statementId: statementId,
      imageUrl: imageUrl,
    );
  }

  /// OCR 추출 시작 (웹앱 extractStatementData와 동일)
  /// ocr-transaction-statement Edge Function을 process_specific 모드로 호출
  static Future<void> extractStatementData(
    String statementId,
    String imageUrl,
  ) async {
    await _supabase.functions.invoke(
      'ocr-transaction-statement',
      body: {
        'statementId': statementId,
        'imageUrl': imageUrl,
        'mode': 'process_specific',
      },
    );
  }

  /// 대기열 처리 트리거 (웹앱 kickQueue와 동일)
  /// ocr-transaction-statement Edge Function을 process_next 모드로 호출
  static Future<void> kickQueue() async {
    try {
      await _supabase.functions.invoke(
        'ocr-transaction-statement',
        body: {'mode': 'process_next'},
      );
    } catch (_) {
      // 큐 처리 실패는 무시 (다음 호출에서 재시도)
    }
  }

  static Future<List<TransactionStatementSummary>> fetchStatements() async {
    final response = await _supabase
        .from('transaction_statements')
        .select(
          'id, image_url, file_name, status, statement_mode, uploaded_at, '
          'uploaded_by_name, statement_date, vendor_name, grand_total, '
          'confirmed_by_name',
        )
        .order('uploaded_at', ascending: false);

    final data = List<Map<String, dynamic>>.from(response);
    return data.map(TransactionStatementSummary.fromMap).toList();
  }

  // ── 공통 헬퍼 ──────────────────────────────────────────

  /// 이미지를 Storage에 업로드하고 public URL을 반환
  static Future<String> _uploadImageToStorage(XFile imageFile) async {
    final filePath = imageFile.path;
    final dotIndex = filePath.lastIndexOf('.');
    final fileExtension =
        dotIndex != -1 ? filePath.substring(dotIndex).toLowerCase() : '.jpg';
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

    return _supabase.storage.from('receipt-images').getPublicUrl(storagePath);
  }

  static String _generateFileName(String extension) {
    final rand = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = List.generate(6, (_) => rand.nextInt(36))
        .map((n) => n.toRadixString(36))
        .join();
    final safeExtension = extension.isNotEmpty ? extension : '.jpg';
    return 'ts_${timestamp}_$randomSuffix$safeExtension';
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
