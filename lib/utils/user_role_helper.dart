/// 사용자 역할 관리를 위한 유틸리티 클래스
/// 모든 역할 체크 로직을 중앙화하여 관리
class UserRoleHelper {
  // ============== Purchase Roles ==============
  static const String LEAD_BUYER = 'lead buyer';
  static const String APP_ADMIN = 'app_admin';
  static const String MIDDLE_MANAGER = 'middle_manager';
  static const String FINAL_APPROVER = 'final_approver';
  static const String RAW_MATERIAL_MANAGER = 'raw_material_manager';
  static const String CONSUMABLE_MANAGER = 'consumable_manager';

  // ============== Attendance Roles ==============
  static const String ADMIN = 'admin';
  static const String SUPERADMIN = 'superadmin';
  static const String SUPERVISOR = 'supervisor';
  static const String DEV3_MANAGER = '개발3팀_manager';
  static const String CAD_MANAGER = 'CAD_manager';
  static const String DEV_MANAGER = '개발팀_manager';
  static const String SUPPORT_MANAGER = '경영지원팀_manager';
  static const String LAB_MANAGER = '연구소_manager';

  // ============== Purchase Role Checks ==============
  
  /// app_admin 여부 확인
  static bool isAppAdmin(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(APP_ADMIN);
  }

  /// lead buyer 여부 확인 (app_admin 포함)
  static bool isLeadBuyer(List<dynamic>? roles) {
    if (roles == null) return false;
    // app_admin이면 모든 권한 가짐
    return roles.contains(LEAD_BUYER) || roles.contains(APP_ADMIN);
  }

  /// lead buyer 또는 app_admin 여부 (순수 lead buyer 체크용)
  static bool isPureLeadBuyer(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(LEAD_BUYER);
  }

  /// middle_manager 여부 확인
  static bool isMiddleManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(MIDDLE_MANAGER);
  }

  /// final_approver 여부 확인
  static bool isFinalApprover(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(FINAL_APPROVER);
  }

  /// raw_material_manager 여부 확인
  static bool isRawMaterialManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(RAW_MATERIAL_MANAGER);
  }

  /// consumable_manager 여부 확인
  static bool isConsumableManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(CONSUMABLE_MANAGER);
  }

  /// 일반 직원 여부 확인 (특별 권한 없는 직원)
  static bool isRegularEmployee(List<dynamic>? roles) {
    if (roles == null) return true;
    return !roles.contains(APP_ADMIN) &&
           !roles.contains(MIDDLE_MANAGER) &&
           !roles.contains(FINAL_APPROVER) &&
           !roles.contains(LEAD_BUYER);
  }

  /// 구매현황 조회 권한 여부
  static bool canViewPurchaseStatus(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(LEAD_BUYER) || roles.contains(APP_ADMIN);
  }

  /// 발주 승인 권한 여부
  static bool hasPurchaseApprovalAuth(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(MIDDLE_MANAGER) ||
           roles.contains(FINAL_APPROVER) ||
           roles.contains(RAW_MATERIAL_MANAGER) ||
           roles.contains(CONSUMABLE_MANAGER) ||
           roles.contains(APP_ADMIN);
  }

  /// 최종 승인 권한이 있는 역할인지 확인
  static bool canFinalApprove(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(FINAL_APPROVER) || roles.contains(APP_ADMIN);
  }

  /// 발주 카테고리 관리 권한 확인
  static bool canManageRawMaterial(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(RAW_MATERIAL_MANAGER) && roles.contains(FINAL_APPROVER);
  }

  /// 구매 요청 카테고리 관리 권한 확인
  static bool canManageConsumable(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(CONSUMABLE_MANAGER) && roles.contains(FINAL_APPROVER);
  }

  // ============== Attendance Role Checks ==============
  
  /// admin 여부 확인
  static bool isAdmin(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(ADMIN);
  }

  /// superadmin 여부 확인
  static bool isSuperAdmin(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(SUPERADMIN);
  }

  /// admin 또는 superadmin 여부
  static bool isAdminOrSuper(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(ADMIN) || roles.contains(SUPERADMIN);
  }

  /// supervisor 여부 확인
  static bool isSupervisor(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(SUPERVISOR);
  }

  /// 부서별 매니저 확인
  static bool isDev3Manager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(DEV3_MANAGER);
  }

  static bool isCadManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(CAD_MANAGER);
  }

  static bool isDevManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(DEV_MANAGER);
  }

  static bool isSupportManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(SUPPORT_MANAGER);
  }

  static bool isLabManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(LAB_MANAGER);
  }

  /// 매니저 권한이 있는지 확인 (어떤 부서든)
  static bool isAnyManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return isDev3Manager(roles) ||
           isCadManager(roles) ||
           isDevManager(roles) ||
           isSupportManager(roles) ||
           isLabManager(roles);
  }

  // ============== Tab Count Calculation ==============
  
  /// ApprovalScreen 탭 개수 계산
  static int calculateApprovalTabCount({
    required List<dynamic>? purchaseRoles,
    required List<dynamic>? attendanceRoles,
  }) {
    // lead buyer인 경우: 구매현황 + 입고현황 = 2개
    if (isLeadBuyer(purchaseRoles)) {
      return 2;
    }
    
    // 일반 직원인 경우: 입고대기만 = 1개
    if (isRegularEmployee(purchaseRoles)) {
      return 1;
    }
    
    // 그 외의 경우
    int tabCount = 2; // 기본: 연차/출장 + 입고대기
    
    if (hasPurchaseApprovalAuth(purchaseRoles)) {
      tabCount++; // 발주승인 탭 추가
    }
    
    if (canViewPurchaseStatus(purchaseRoles)) {
      tabCount++; // 구매대기 탭 추가
    }
    
    return tabCount;
  }

  // ============== Pending Count Calculation ==============
  
  /// 발주 대기 건수 계산용 역할 필터
  static Map<String, bool> getPurchaseCountRoles(List<dynamic>? roles) {
    return {
      'isAppAdmin': isAppAdmin(roles),
      'isMiddleManager': isMiddleManager(roles),
      'isRawMaterialManager': isRawMaterialManager(roles),
      'isConsumableManager': isConsumableManager(roles),
      'canManageRawMaterial': canManageRawMaterial(roles),
      'canManageConsumable': canManageConsumable(roles),
    };
  }

  // ============== Utility Methods ==============
  
  /// 역할 리스트를 안전하게 파싱
  static List<dynamic> parseRoles(dynamic roles) {
    if (roles == null) return [];
    if (roles is List) return roles;
    if (roles is String) return [roles];
    return [];
  }

  /// 역할 이름을 한글로 변환
  static String getRoleDisplayName(String role) {
    switch (role) {
      case APP_ADMIN:
        return '앱 관리자';
      case LEAD_BUYER:
        return '구매 담당자';
      case MIDDLE_MANAGER:
        return '중간 관리자';
      case FINAL_APPROVER:
        return '최종 승인자';
      case RAW_MATERIAL_MANAGER:
        return '원자재 관리자';
      case CONSUMABLE_MANAGER:
        return '소모품 관리자';
      case ADMIN:
        return '관리자';
      case SUPERADMIN:
        return '최고 관리자';
      case SUPERVISOR:
        return '감독자';
      default:
        return role;
    }
  }

  /// 사용자가 가진 모든 권한을 문자열로 표시
  static String getRolesDescription({
    List<dynamic>? purchaseRoles,
    List<dynamic>? attendanceRoles,
  }) {
    final List<String> descriptions = [];
    
    // Purchase roles
    if (isAppAdmin(purchaseRoles)) descriptions.add('앱 관리자');
    if (isPureLeadBuyer(purchaseRoles)) descriptions.add('구매 담당자');
    if (isMiddleManager(purchaseRoles)) descriptions.add('중간 관리자');
    if (isFinalApprover(purchaseRoles)) descriptions.add('최종 승인자');
    if (isRawMaterialManager(purchaseRoles)) descriptions.add('원자재 관리자');
    if (isConsumableManager(purchaseRoles)) descriptions.add('소모품 관리자');
    
    // Attendance roles
    if (isSuperAdmin(attendanceRoles)) descriptions.add('최고 관리자');
    else if (isAdmin(attendanceRoles)) descriptions.add('관리자');
    if (isSupervisor(attendanceRoles)) descriptions.add('감독자');
    if (isAnyManager(attendanceRoles)) descriptions.add('부서 매니저');
    
    return descriptions.isEmpty ? '일반 직원' : descriptions.join(', ');
  }
}