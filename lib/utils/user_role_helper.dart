/// 사용자 역할 관리를 위한 유틸리티 클래스
/// 모든 역할 체크 로직을 중앙화하여 관리
///
/// [2차 마이그레이션 완료] roles 통합 칼럼만 사용
class UserRoleHelper {
  // ============== Role Constants ==============
  static const String leadBuyer = 'lead buyer';
  static const String superadmin = 'superadmin';
  static const String middleManager = 'middle_manager';
  static const String finalApprover = 'final_approver';
  static const String rawMaterialManager = 'raw_material_manager';
  static const String consumableManager = 'consumable_manager';
  static const String hr = 'hr';
  static const String admin = 'admin';
  static const String supervisor = 'supervisor';
  static const String dev3Manager = '개발3팀_manager';
  static const String cadManager = 'CAD_manager';
  static const String devManager = '개발팀_manager';
  static const String supportManager = '경영팀_manager';
  static const String labManager = '연구소_manager';

  // ============== 통합 역할 추출 ==============

  /// employee Map에서 통합 역할 리스트를 추출 (roles 칼럼 사용)
  static List<dynamic> getRoles(Map<String, dynamic>? employee) {
    if (employee == null) return [];
    return parseRoles(employee['roles']);
  }

  // ============== Role Checks ==============

  /// superadmin 여부 확인
  static bool isAppAdmin(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(superadmin);
  }

  /// lead buyer 여부 확인 (superadmin 포함)
  static bool isLeadBuyer(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(leadBuyer) || isAppAdmin(roles);
  }

  /// 순수 lead buyer 체크 (superadmin 제외)
  static bool isPureLeadBuyer(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(leadBuyer);
  }

  /// middle_manager 여부 확인
  static bool isMiddleManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(middleManager);
  }

  /// final_approver 여부 확인
  static bool isFinalApprover(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(finalApprover);
  }

  /// raw_material_manager 여부 확인
  static bool isRawMaterialManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(rawMaterialManager);
  }

  /// consumable_manager 여부 확인
  static bool isConsumableManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(consumableManager);
  }

  /// hr 여부 확인
  static bool isHr(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(hr);
  }

  /// 전체 근태 관리 권한 여부 (hr 또는 superadmin)
  static bool canManageAttendance(List<dynamic>? roles) {
    if (roles == null) return false;
    return isAppAdmin(roles) || isHr(roles);
  }

  /// 일반 직원 여부 확인 (특별 권한 없는 직원)
  static bool isRegularEmployee(List<dynamic>? roles) {
    if (roles == null) return true;
    return !isAppAdmin(roles) &&
           !roles.contains(middleManager) &&
           !roles.contains(finalApprover) &&
           !roles.contains(leadBuyer) &&
           !roles.contains(hr);
  }

  /// 구매현황 조회 권한 여부
  static bool canViewPurchaseStatus(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(leadBuyer) || isAppAdmin(roles);
  }

  /// 발주 승인 권한 여부
  static bool hasPurchaseApprovalAuth(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(middleManager) ||
           roles.contains(finalApprover) ||
           roles.contains(rawMaterialManager) ||
           roles.contains(consumableManager) ||
           isAppAdmin(roles);
  }

  /// 최종 승인 권한이 있는 역할인지 확인
  static bool canFinalApprove(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(finalApprover) || isAppAdmin(roles);
  }

  /// 발주 카테고리 관리 권한 확인
  static bool canManageRawMaterial(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(rawMaterialManager) && roles.contains(finalApprover);
  }

  /// 구매 요청 카테고리 관리 권한 확인
  static bool canManageConsumable(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(consumableManager) && roles.contains(finalApprover);
  }

  // ============== Attendance Role Checks ==============

  /// admin 여부 확인
  static bool isAdmin(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(admin);
  }

  /// superadmin 여부 확인
  static bool isSuperAdmin(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(superadmin);
  }

  /// admin 또는 superadmin 여부
  static bool isAdminOrSuper(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(admin) || isSuperAdmin(roles);
  }

  /// supervisor 여부 확인
  static bool isSupervisor(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(supervisor);
  }

  /// 부서별 매니저 확인
  static bool isDev3Manager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(dev3Manager);
  }

  static bool isCadManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(cadManager);
  }

  static bool isDevManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(devManager);
  }

  static bool isSupportManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(supportManager);
  }

  static bool isLabManager(List<dynamic>? roles) {
    if (roles == null) return false;
    return roles.contains(labManager);
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

  /// ApprovalScreen 탭 개수 계산 (통합 roles 사용)
  static int calculateApprovalTabCount(List<dynamic>? roles) {
    // lead buyer인 경우: 구매현황 + 입고현황 = 2개
    if (isLeadBuyer(roles)) {
      return 2;
    }

    // 일반 직원인 경우: 입고대기만 = 1개
    if (isRegularEmployee(roles)) {
      return 1;
    }

    // 그 외의 경우
    int tabCount = 2; // 기본: 연차/출장 + 입고대기

    if (hasPurchaseApprovalAuth(roles)) {
      tabCount++; // 발주승인 탭 추가
    }

    if (canViewPurchaseStatus(roles)) {
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
      case superadmin:
        return '최고 관리자';
      case leadBuyer:
        return '구매 담당자';
      case middleManager:
        return '중간 관리자';
      case finalApprover:
        return '최종 승인자';
      case rawMaterialManager:
        return '원자재 관리자';
      case consumableManager:
        return '소모품 관리자';
      case hr:
        return 'hr 담당자';
      case admin:
        return '관리자';
      case supervisor:
        return '감독자';
      default:
        return role;
    }
  }

  /// 사용자가 가진 모든 권한을 문자열로 표시 (통합 roles 사용)
  static String getRolesDescription(List<dynamic>? roles) {
    final List<String> descriptions = [];

    if (isAppAdmin(roles)) descriptions.add('최고 관리자');
    if (isPureLeadBuyer(roles)) descriptions.add('구매 담당자');
    if (isMiddleManager(roles)) descriptions.add('중간 관리자');
    if (isFinalApprover(roles)) descriptions.add('최종 승인자');
    if (isRawMaterialManager(roles)) descriptions.add('원자재 관리자');
    if (isConsumableManager(roles)) descriptions.add('소모품 관리자');
    if (isHr(roles)) descriptions.add('hr 담당자');
    if (!isAppAdmin(roles) && isAdmin(roles)) descriptions.add('관리자');
    if (isSupervisor(roles)) descriptions.add('감독자');
    if (isAnyManager(roles)) descriptions.add('부서 매니저');

    return descriptions.isEmpty ? '일반 직원' : descriptions.join(', ');
  }
}
