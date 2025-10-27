import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

/// 영수증 업로드 서비스
class ReceiptUploadService {
  static final _supabase = Supabase.instance.client;
  static final _imagePicker = ImagePicker();

  /// 카메라로 영수증 촬영 및 업로드 (독립적)
  static Future<String?> captureAndUploadReceipt({
    required String userEmail,
  }) async {
    try {
      // 1. 카메라로 사진 촬영
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // 압축 (파일 크기 줄이기)
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo == null) {
        return null;
      }

      // 2. Supabase Storage에 업로드
      return await _uploadReceiptImage(
        photo: photo,
        userEmail: userEmail,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 갤러리에서 영수증 선택 및 업로드 (독립적)
  static Future<String?> selectAndUploadReceipt({
    required String userEmail,
  }) async {
    try {
      // 1. 갤러리에서 이미지 선택
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo == null) {
        return null;
      }

      // 2. Supabase Storage에 업로드
      return await _uploadReceiptImage(
        photo: photo,
        userEmail: userEmail,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 영수증 이미지 업로드 (내부 함수) - purchase_receipts 전용 (독립적)
  static Future<String?> _uploadReceiptImage({
    required XFile photo,
    required String userEmail,
  }) async {
    String userName = '';
    
    // 사용자 이름 가져오기
    try {
      final employee = await _supabase
          .from('employees')
          .select('name')
          .eq('email', userEmail)
          .single();
      userName = employee['name'] ?? '';
    } catch (e) {
      // 사용자 이름 조회 실패시 빈 문자열 유지
    }
    
    try {
      final now = DateTime.now();
      final fileExtension = path.extension(photo.path);
      
      // 파일명 자동 생성: rec + YYMMDDHHmm (예: rec2510270316)
      final fileName = 'rec${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
      // 파일 경로: receipts/{년도-월}/{fileName}.jpg (예: receipts/2025-10/rec2510270316.jpg)
      final monthFolder = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final filePath = 'receipts/$monthFolder/$fileName$fileExtension';

      // Supabase Storage에 업로드
      final bytes = await photo.readAsBytes();
      await _supabase.storage.from('receipt-images').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: _getContentType(fileExtension),
          upsert: false, // 덮어쓰기 방지
        ),
      );

      // Public URL 생성
      final publicUrl = _supabase.storage
          .from('receipt-images')
          .getPublicUrl(filePath);

      // 파일 크기 가져오기
      final fileSize = bytes.length;

      // DB 저장: purchase_receipts 테이블 (독립적 시스템)
      await _supabase.from('purchase_receipts').insert({
        'receipt_image_url': publicUrl,
        'file_name': '$fileName$fileExtension', // rec2510270316.jpg
        'file_size': fileSize,
        'uploaded_by': userEmail,
        'uploaded_by_name': userName,
        'uploaded_at': DateTime.now().toUtc().toIso8601String(),
      });

      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// 영수증 삭제 - purchase_receipts 전용
  static Future<void> deleteReceipt({
    required int receiptId,
    required String receiptUrl,
  }) async {
    try {
      // 1. Storage에서 파일 삭제
      final uri = Uri.parse(receiptUrl);
      final filePath = uri.pathSegments.sublist(
        uri.pathSegments.indexOf('receipt-images') + 1,
      ).join('/');

      await _supabase.storage.from('receipt-images').remove([filePath]);

      // 2. purchase_receipts 테이블에서 레코드 삭제 (ID로 정확히 삭제)
      await _supabase
          .from('purchase_receipts')
          .delete()
          .eq('id', receiptId);

    } catch (e) {
      rethrow;
    }
  }

  /// 파일 확장자에 따른 Content-Type 반환
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

  /// 독립적인 영수증 업로드
  static Future<String?> uploadReceiptIndependent({
    required String userEmail,
    required ImageSource source,
    String? memo,
  }) async {
    try {
      // 1. 이미지 선택
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo == null) {
        return null;
      }

      // 2. 사용자 이름 가져오기
      String userName = '';
      try {
        final employee = await _supabase
            .from('employees')
            .select('name')
            .eq('email', userEmail)
            .single();
        userName = employee['name'] ?? '';
      } catch (e) {
        // 사용자 이름 조회 실패시 빈 문자열 유지
      }

      // 3. 파일 업로드
      final now = DateTime.now();
      final fileExtension = path.extension(photo.path);
      final fileName = 'rec${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
      // 파일 경로: receipts/{년도-월}/{fileName}.jpg (예: receipts/2025-10/rec2510270316.jpg)
      final monthFolder = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final filePath = 'receipts/$monthFolder/$fileName$fileExtension';

      final bytes = await photo.readAsBytes();
      await _supabase.storage.from('receipt-images').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: _getContentType(fileExtension),
          upsert: false,
        ),
      );

      final publicUrl = _supabase.storage
          .from('receipt-images')
          .getPublicUrl(filePath);

      // 4. purchase_receipts 테이블에 저장 (독립적 시스템)
      await _supabase.from('purchase_receipts').insert({
        'receipt_image_url': publicUrl,
        'file_name': '$fileName$fileExtension',
        'file_size': bytes.length,
        'uploaded_by': userEmail,
        'uploaded_by_name': userName,
        'memo': memo,
        'uploaded_at': DateTime.now().toUtc().toIso8601String(),
      });

      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// 영수증 선택 다이얼로그 (독립적 업로드용)
  static Future<String?> showIndependentReceiptUploadDialog({
    required BuildContext context,
    required String userEmail,
    String? memo,
  }) async {
    return await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF007AFF)),
              title: const Text('카메라로 촬영'),
              onTap: () async {
                try {
                  final url = await uploadReceiptIndependent(
                    userEmail: userEmail,
                    source: ImageSource.camera,
                    memo: memo,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, url);
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // 에러 시에만 다이얼로그 닫기
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('업로드 실패: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF34C759)),
              title: const Text('갤러리에서 선택'),
              onTap: () async {
                try {
                  final url = await uploadReceiptIndependent(
                    userEmail: userEmail,
                    source: ImageSource.gallery,
                    memo: memo,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, url);
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // 에러 시에만 다이얼로그 닫기
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('업로드 실패: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Color(0xFF8E8E93)),
              title: const Text('취소'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

