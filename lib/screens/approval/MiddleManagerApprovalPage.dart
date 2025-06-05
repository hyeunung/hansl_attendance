import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'po_preview_page.dart'; // PO 미리보기 페이지 경로 (같은 폴더에 생성 예정)

class MiddleManagerApprovalPage extends StatefulWidget {
  const MiddleManagerApprovalPage({Key? key}) : super(key: key);

  @override
  _MiddleManagerApprovalPageState createState() => _MiddleManagerApprovalPageState();
}

class _MiddleManagerApprovalPageState extends State<MiddleManagerApprovalPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _isLoading = true);
    final response = await supabase
        .from('purchase_requests')
        .select('
          id,
          request_type,
          request_date,
          total_amount,
          currency,
          po_file_url,
          vendors(vendor_name)
        ')
        .eq('payment_status', '대기')
        .order('request_date', ascending: true)
        .execute();
    if (response.error == null) {
      setState(() {
        _pendingRequests = response.data;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 불러오기 실패: ${response.error!.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('발주 승인 (중간 관리자)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _pendingRequests.length,
              itemBuilder: (context, index) {
                final pr = _pendingRequests[index];
                final id = pr['id'];
                final type = pr['request_type']; // '원자재' or '소모품'
                final vendorName = pr['vendors']?['vendor_name'] ?? '-';
                final requestDate = pr['request_date'] ?? '-';
                final totalAmount = pr['total_amount'] ?? 0;
                final currency = pr['currency'] ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text('발주번호: #$id ($type)'),
                    subtitle: Text('$vendorName • $requestDate • $currency $totalAmount'),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PoPreviewPage(
                            purchaseRequestId: id,
                            initialStatus: '대기',
                            onApprove: () async {
                              final updateRes = await supabase
                                  .from('purchase_requests')
                                  .update({'payment_status': '확인'})
                                  .eq('id', id)
                                  .execute();
                              if (updateRes.error == null) {
                                Navigator.of(context).pop();
                                _loadPendingRequests();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('승인 실패: ${updateRes.error!.message}')),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final updateRes = await supabase
                            .from('purchase_requests')
                            .update({'payment_status': '확인'})
                            .eq('id', id)
                            .execute();
                        if (updateRes.error == null) {
                          _loadPendingRequests();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('승인 실패: ${updateRes.error!.message}')),
                          );
                        }
                      },
                      child: const Text('확인'),
                    ),
                  ),
                );
              },
            ),
    );
  }
} 