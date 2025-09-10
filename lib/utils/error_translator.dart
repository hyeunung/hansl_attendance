import 'package:flutter/foundation.dart';

/// 에러 메시지를 한글로 번역하는 유틸리티
class ErrorTranslator {
  /// Supabase/인증 관련 에러를 한글로 번역
  static String translate(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // 디버그 모드에서는 원본 에러도 출력
    if (kDebugMode) {
      print('🔴 원본 에러: $error');
    }

    // 인증 관련 에러
    if (errorStr.contains('invalid login credentials') ||
        errorStr.contains('invalid email or password')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다';
    }

    if (errorStr.contains('email not confirmed')) {
      return '이메일 인증이 완료되지 않았습니다';
    }

    if (errorStr.contains('user not found')) {
      return '등록되지 않은 사용자입니다';
    }

    if (errorStr.contains('email already registered') ||
        errorStr.contains('user already registered')) {
      return '이미 등록된 이메일입니다';
    }

    if (errorStr.contains('password should be at least')) {
      return '비밀번호는 최소 6자 이상이어야 합니다';
    }

    if (errorStr.contains('invalid email')) {
      return '올바른 이메일 형식이 아닙니다';
    }

    if (errorStr.contains('session expired') ||
        errorStr.contains('jwt expired')) {
      return '로그인 세션이 만료되었습니다. 다시 로그인해주세요';
    }

    if (errorStr.contains('refresh token') ||
        errorStr.contains('token is invalid')) {
      return '인증 토큰이 유효하지 않습니다. 다시 로그인해주세요';
    }

    // 네트워크 관련 에러
    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('socketexception')) {
      return '네트워크 연결을 확인해주세요';
    }

    if (errorStr.contains('timeout')) {
      return '요청 시간이 초과되었습니다. 다시 시도해주세요';
    }

    if (errorStr.contains('no internet')) {
      return '인터넷 연결이 없습니다';
    }

    // 권한 관련 에러
    if (errorStr.contains('permission denied') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('not authorized')) {
      return '권한이 없습니다. 관리자에게 문의하세요';
    }

    if (errorStr.contains('forbidden') || errorStr.contains('access denied')) {
      return '접근이 거부되었습니다';
    }

    // 데이터베이스 관련 에러
    if (errorStr.contains('duplicate') || errorStr.contains('already exists')) {
      return '이미 존재하는 데이터입니다';
    }

    if (errorStr.contains('column') && errorStr.contains('does not exist')) {
      return '데이터베이스 구조가 업데이트되지 않았습니다. 관리자에게 문의하세요';
    }

    if (errorStr.contains('not found') || errorStr.contains('does not exist')) {
      return '요청한 데이터를 찾을 수 없습니다';
    }

    if (errorStr.contains('invalid data') ||
        errorStr.contains('validation failed')) {
      return '입력한 데이터가 올바르지 않습니다';
    }

    if (errorStr.contains('constraint') || errorStr.contains('violates')) {
      return '데이터 제약 조건을 위반했습니다';
    }

    // Row Level Security (RLS) 에러
    if (errorStr.contains('new row violates row-level security') ||
        errorStr.contains('rls')) {
      return '데이터 접근 권한이 없습니다. 관리자에게 문의하세요';
    }

    // 출퇴근 관련 에러
    if (errorStr.contains('already checked in')) {
      return '이미 출근 처리되었습니다';
    }

    if (errorStr.contains('not checked in')) {
      return '출근 기록이 없습니다';
    }

    if (errorStr.contains('already checked out')) {
      return '이미 퇴근 처리되었습니다';
    }

    if (errorStr.contains('location')) {
      return '위치 정보를 확인할 수 없습니다';
    }

    // 연차/출장 관련 에러
    if (errorStr.contains('insufficient leave') ||
        errorStr.contains('not enough leave')) {
      return '연차가 부족합니다';
    }

    if (errorStr.contains('overlapping leave') ||
        errorStr.contains('duplicate leave')) {
      return '해당 기간에 이미 신청한 연차/출장이 있습니다';
    }

    if (errorStr.contains('past date')) {
      return '과거 날짜는 신청할 수 없습니다';
    }

    if (errorStr.contains('weekend') || errorStr.contains('holiday')) {
      return '주말/공휴일은 신청할 수 없습니다';
    }

    // 파일 관련 에러
    if (errorStr.contains('file not found')) {
      return '파일을 찾을 수 없습니다';
    }

    if (errorStr.contains('file too large')) {
      return '파일 크기가 너무 큽니다';
    }

    if (errorStr.contains('invalid file type')) {
      return '지원하지 않는 파일 형식입니다';
    }

    // 서버 관련 에러
    if (errorStr.contains('server error') ||
        errorStr.contains('internal server')) {
      return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요';
    }

    if (errorStr.contains('service unavailable') || errorStr.contains('503')) {
      return '서비스를 일시적으로 사용할 수 없습니다';
    }

    if (errorStr.contains('bad gateway') || errorStr.contains('502')) {
      return '서버 연결에 문제가 있습니다';
    }

    // Supabase 특정 에러
    if (errorStr.contains('postgrest')) {
      return '데이터베이스 요청 중 오류가 발생했습니다';
    }

    if (errorStr.contains('realtime')) {
      return '실시간 연결에 문제가 있습니다';
    }

    if (errorStr.contains('storage')) {
      return '파일 저장소 오류가 발생했습니다';
    }

    // 기타 일반적인 에러
    if (errorStr.contains('invalid')) {
      return '올바르지 않은 요청입니다';
    }

    if (errorStr.contains('failed')) {
      return '작업을 완료할 수 없습니다';
    }

    if (errorStr.contains('error')) {
      return '오류가 발생했습니다';
    }

    // 알 수 없는 에러는 원본 메시지의 일부를 포함하여 반환
    if (error.toString().length > 100) {
      return '오류가 발생했습니다. 관리자에게 문의하세요';
    }

    // 짧은 에러는 그대로 반환 (이미 한글일 수 있음)
    return error.toString();
  }

  /// 에러 타입에 따른 아이콘 반환
  static String getErrorIcon(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return '📡';
    }
    if (errorStr.contains('auth') ||
        errorStr.contains('login') ||
        errorStr.contains('password')) {
      return '🔐';
    }
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return '🚫';
    }
    if (errorStr.contains('not found')) {
      return '🔍';
    }
    if (errorStr.contains('server')) {
      return '🖥️';
    }
    if (errorStr.contains('time')) {
      return '⏰';
    }
    return '❌';
  }

  /// 사용자 친화적인 에러 메시지 생성
  static String getUserFriendlyMessage(dynamic error) {
    final icon = getErrorIcon(error);
    final message = translate(error);
    return '$icon $message';
  }
}
