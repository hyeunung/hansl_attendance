// 앱에서 사용하는 문자열 상수들을 모아놓는 클래스
class AppStrings {
  // 기본 문자열
  static const String appName = 'HANSL';
  static const String loginTitle = '로그인';
  static const String emailHint = '이메일';
  static const String passwordHint = '비밀번호';
  static const String loginButton = '로그인';
  static const String logoutButton = '로그아웃';
  
  // 에러 메시지
  static const String loginError = '로그인에 실패했습니다.';
  static const String networkError = '네트워크 연결을 확인해주세요.';
  
  // Admin 정보
  static const String adminEmail = 'hyun-woong.jeong@hansl.com';
  static const String adminName = '정현웅';
  
  // Manager 목록 및 부서 매핑
  static const List<String> managerNames = [
    '양승진',  // 개발팀_manager (개발1팀, 개발2팀)
    '최창열',  // 개발3팀_manager (개발3팀)
    '조근일',  // 연구소_manager (연구소)
    '황연순',  // 경영지원팀_manager (경영지원팀)
    '이정화',  // CAD_manager (CAD)
  ];
  
  // 부서별 Manager 매핑
  static const Map<String, String> departmentToManager = {
    '개발1팀': '양승진',
    '개발2팀': '양승진',
    '개발3팀': '최창열',
    '연구소': '조근일',
    '경영지원팀': '황연순',
    'CAD': '이정화',
  };
  
  // Manager별 담당 부서
  static const Map<String, List<String>> managerToDepartments = {
    '양승진': ['개발1팀', '개발2팀'],
    '최창열': ['개발3팀'],
    '조근일': ['연구소'],
    '황연순': ['경영지원팀'],
    '이정화': ['CAD'],
  };
}
