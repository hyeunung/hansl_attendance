import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PoPreviewPage extends StatefulWidget {
  final int purchaseRequestId;
  final String initialStatus; // '대기' 또는 '확인'
  final Future<void> Function() onApprove;

  const PoPreviewPage({
    Key? key,
    required this.purchaseRequestId,
    required this.initialStatus,
    required this.onApprove,
  }) : super(key: key);

  @override
  _PoPreviewPageState createState() => _PoPreviewPageState();
}

class _PoPreviewPageState extends State<PoPreviewPage> {
  String? localFilePath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _downloadAndLoadPdf();
  }

  Future<void> _downloadAndLoadPdf() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('purchase_requests')
        .select('po_file_url')
        .eq('id', widget.purchaseRequestId)
        .single();

    if (response['po_file_url'] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('발주서가 없습니다.')));
      setState(() => _isLoading = false);
      return;
    }

    final poUrl = response['po_file_url'];
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/po_${widget.purchaseRequestId}.pdf';
      final pdfResponse = await http.get(Uri.parse(poUrl));
      final file = File(filePath);
      await file.writeAsBytes(pdfResponse.bodyBytes);
      setState(() {
        localFilePath = filePath;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('발주서 다운로드 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('발주서 미리보기 (#${widget.purchaseRequestId})')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : localFilePath == null
          ? const Center(child: Text('발주서 로드 실패'))
          : Column(
              children: [
                Expanded(
                  child: PDFView(
                    filePath: localFilePath!,
                    enableSwipe: true,
                    swipeHorizontal: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      await widget.onApprove();
                    },
                    child: Text(
                      widget.initialStatus == '대기' ? '확인(승인)' : '결제 승인',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
