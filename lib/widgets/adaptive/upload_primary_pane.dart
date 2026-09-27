import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';

/// 펼친 폴더블에서 명세서/영수증 탭 오른쪽에 기본으로 표시되는 업로드 패널.
/// 폰에서는 같은 동작을 하단 업로드 버튼(FAB) 메뉴가 담당한다.
class UploadPrimaryPane extends StatelessWidget {
  const UploadPrimaryPane({
    super.key,
    required this.title,
    required this.description,
    required this.onCamera,
    required this.onGallery,
  });

  final String title;
  final String description;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: AppBarTitle(title),
      ),
      body: ListView(
        padding: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 12)),
        children: [
          FlatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FlatCardHeader(
                  title: '새로 올리기',
                  icon: Icons.upload,
                  iconColor: AppColors.primary,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    ResponsiveUtils.spacing(context, 14),
                    ResponsiveUtils.spacing(context, 12),
                    ResponsiveUtils.spacing(context, 14),
                    ResponsiveUtils.spacing(context, 4),
                  ),
                  child: Text(
                    description,
                    style: AppTextStyles.listSubtitle(context),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 14)),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCamera,
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('촬영'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onGallery,
                          icon: const Icon(Icons.photo_outlined, size: 18),
                          label: const Text('보관함'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 24),
              vertical: ResponsiveUtils.spacing(context, 8),
            ),
            child: Text(
              '왼쪽 목록에서 항목을 선택하면 이 자리에 상세가 표시됩니다.',
              style: AppTextStyles.listSubtitle(context),
            ),
          ),
        ],
      ),
    );
  }
}
