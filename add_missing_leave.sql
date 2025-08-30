-- 누락된 연차 데이터 추가 SQL
-- 생성 시간: 2025-08-19T02:25:52.461Z
-- 총 92개의 레코드 추가

BEGIN;

-- 1. leave 테이블에 누락된 연차 추가
-- 양승진 8월 1일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('양승진', 'ysj@hansl.com', 'annual', '2025-08-01', '2025-08-01', 'approved', '개인 사유', NOW());

-- 최창열 2월 24일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('최창열', 'ccy@hansl.com', 'half_pm', '2025-02-24', '2025-02-24', 'approved', '개인 사유', NOW());

-- 최창열 8월 5일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('최창열', 'ccy@hansl.com', 'half_pm', '2025-08-05', '2025-08-05', 'approved', '개인 사유', NOW());

-- 김은정 4월 23일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김은정', 'kej@hansl.com', 'annual', '2025-04-23', '2025-04-23', 'approved', '개인 사유', NOW());

-- 김은정 4월 28일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김은정', 'kej@hansl.com', 'half_pm', '2025-04-28', '2025-04-28', 'approved', '개인 사유', NOW());

-- 김은정 7월 16일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김은정', 'kej@hansl.com', 'annual', '2025-07-16', '2025-07-16', 'approved', '개인 사유', NOW());

-- 김은정 7월 30일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김은정', 'kej@hansl.com', 'annual', '2025-07-30', '2025-07-30', 'approved', '개인 사유', NOW());

-- 김은정 7월 31일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김은정', 'kej@hansl.com', 'annual', '2025-07-31', '2025-07-31', 'approved', '개인 사유', NOW());

-- 김은정 8월 1일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김은정', 'kej@hansl.com', 'annual', '2025-08-01', '2025-08-01', 'approved', '개인 사유', NOW());

-- 김은정 8월 14일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김은정', 'kej@hansl.com', 'half_am', '2025-08-14', '2025-08-14', 'approved', '개인 사유', NOW());

-- 이정화 2월 7일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이정화', 'ljh@hansl.com', 'half_pm', '2025-02-07', '2025-02-07', 'approved', '개인 사유', NOW());

-- 이정화 4월 2일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이정화', 'ljh@hansl.com', 'annual', '2025-04-02', '2025-04-02', 'approved', '개인 사유', NOW());

-- 이정화 7월 18일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이정화', 'ljh@hansl.com', 'annual', '2025-07-18', '2025-07-18', 'approved', '개인 사유', NOW());

-- 이정화 7월 21일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이정화', 'ljh@hansl.com', 'annual', '2025-07-21', '2025-07-21', 'approved', '개인 사유', NOW());

-- 이정화 7월 22일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이정화', 'ljh@hansl.com', 'annual', '2025-07-22', '2025-07-22', 'approved', '개인 사유', NOW());

-- 이정화 7월 23일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이정화', 'ljh@hansl.com', 'annual', '2025-07-23', '2025-07-23', 'approved', '개인 사유', NOW());

-- 이정화 7월 24일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이정화', 'ljh@hansl.com', 'annual', '2025-07-24', '2025-07-24', 'approved', '개인 사유', NOW());

-- 이정화 7월 25일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이정화', 'ljh@hansl.com', 'annual', '2025-07-25', '2025-07-25', 'approved', '개인 사유', NOW());

-- 이정화 8월 1일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이정화', 'ljh@hansl.com', 'annual', '2025-08-01', '2025-08-01', 'approved', '개인 사유', NOW());

-- 하치복 2월 21일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('하치복', 'hcb@hansl.com', 'annual', '2025-02-21', '2025-02-21', 'approved', '개인 사유', NOW());

-- 하치복 7월 31일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('하치복', 'hcb@hansl.com', 'annual', '2025-07-31', '2025-07-31', 'approved', '개인 사유', NOW());

-- 하치복 8월 1일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('하치복', 'hcb@hansl.com', 'annual', '2025-08-01', '2025-08-01', 'approved', '개인 사유', NOW());

-- 김경태 2월 11일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김경태', 'kkt@hansl.com', 'annual', '2025-02-11', '2025-02-11', 'approved', '개인 사유', NOW());

-- 김경태 2월 12일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김경태', 'kkt@hansl.com', 'annual', '2025-02-12', '2025-02-12', 'approved', '개인 사유', NOW());

-- 김경태 2월 13일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김경태', 'kkt@hansl.com', 'annual', '2025-02-13', '2025-02-13', 'approved', '개인 사유', NOW());

-- 김경태 2월 19일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김경태', 'kkt@hansl.com', 'annual', '2025-02-19', '2025-02-19', 'approved', '개인 사유', NOW());

-- 김경태 7월 31일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김경태', 'kkt@hansl.com', 'annual', '2025-07-31', '2025-07-31', 'approved', '개인 사유', NOW());

-- 김경태 8월 1일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김경태', 'kkt@hansl.com', 'annual', '2025-08-01', '2025-08-01', 'approved', '개인 사유', NOW());

-- 조근일 8월 1일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('조근일', 'cgi@hansl.com', 'half_pm', '2025-08-01', '2025-08-01', 'approved', '개인 사유', NOW());

-- 이재형 2월 28일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이재형', 'leejh@hansl.com', 'annual', '2025-02-28', '2025-02-28', 'approved', '개인 사유', NOW());

-- 이재형 7월 7일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이재형', 'leejh@hansl.com', 'annual', '2025-07-07', '2025-07-07', 'approved', '개인 사유', NOW());

-- 이재형 7월 18일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이재형', 'leejh@hansl.com', 'half_pm', '2025-07-18', '2025-07-18', 'approved', '개인 사유', NOW());

-- 이재형 8월 12일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이재형', 'leejh@hansl.com', 'annual', '2025-08-12', '2025-08-12', 'approved', '개인 사유', NOW());

-- 이재형 8월 13일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이재형', 'leejh@hansl.com', 'annual', '2025-08-13', '2025-08-13', 'approved', '개인 사유', NOW());

-- 임소연 2월 28일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('임소연', 'lsy@hansl.com', 'annual', '2025-02-28', '2025-02-28', 'approved', '개인 사유', NOW());

-- 임소연 7월 30일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('임소연', 'lsy@hansl.com', 'annual', '2025-07-30', '2025-07-30', 'approved', '개인 사유', NOW());

-- 임소연 7월 31일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('임소연', 'lsy@hansl.com', 'annual', '2025-07-31', '2025-07-31', 'approved', '개인 사유', NOW());

-- 임소연 8월 1일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('임소연', 'lsy@hansl.com', 'annual', '2025-08-01', '2025-08-01', 'approved', '개인 사유', NOW());

-- 임소연 8월 4일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('임소연', 'lsy@hansl.com', 'annual', '2025-08-04', '2025-08-04', 'approved', '개인 사유', NOW());

-- 김지혜 2월 21일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김지혜', 'ji-hye.kim@hansl.com', 'annual', '2025-02-21', '2025-02-21', 'approved', '개인 사유', NOW());

-- 김지혜 7월 28일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김지혜', 'ji-hye.kim@hansl.com', 'annual', '2025-07-28', '2025-07-28', 'approved', '개인 사유', NOW());

-- 김지혜 7월 29일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김지혜', 'ji-hye.kim@hansl.com', 'annual', '2025-07-29', '2025-07-29', 'approved', '개인 사유', NOW());

-- 김지혜 7월 17일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김지혜', 'ji-hye.kim@hansl.com', 'half_pm', '2025-07-17', '2025-07-17', 'approved', '개인 사유', NOW());

-- 정승후 2월 14일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('정승후', 'seung-hoo.jung@hansl.com', 'half_am', '2025-02-14', '2025-02-14', 'approved', '개인 사유', NOW());

-- 정승후 2월 19일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('정승후', 'seung-hoo.jung@hansl.com', 'half_pm', '2025-02-19', '2025-02-19', 'approved', '개인 사유', NOW());

-- 정승후 7월 18일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('정승후', 'seung-hoo.jung@hansl.com', 'half_pm', '2025-07-18', '2025-07-18', 'approved', '개인 사유', NOW());

-- 정승후 8월 18일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('정승후', 'seung-hoo.jung@hansl.com', 'half_pm', '2025-08-18', '2025-08-18', 'approved', '개인 사유', NOW());

-- 나유성 1월 17일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('나유성', 'yu-seong.na@hansl.com', 'half_am', '2025-01-17', '2025-01-17', 'approved', '개인 사유', NOW());

-- 나유성 1월 17일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('나유성', 'yu-seong.na@hansl.com', 'half_pm', '2025-01-17', '2025-01-17', 'approved', '개인 사유', NOW());

-- 나유성 8월 1일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('나유성', 'yu-seong.na@hansl.com', 'half_am', '2025-08-01', '2025-08-01', 'approved', '개인 사유', NOW());

-- 나유성 8월 14일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('나유성', 'yu-seong.na@hansl.com', 'half_pm', '2025-08-14', '2025-08-14', 'approved', '개인 사유', NOW());

-- 김희승 2월 19일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김희승', 'hee-seung.kim@hansl.com', 'half_am', '2025-02-19', '2025-02-19', 'approved', '개인 사유', NOW());

-- 김희승 7월 31일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김희승', 'hee-seung.kim@hansl.com', 'annual', '2025-07-31', '2025-07-31', 'approved', '개인 사유', NOW());

-- 김희승 7월 1일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김희승', 'hee-seung.kim@hansl.com', 'annual', '2025-07-01', '2025-07-01', 'approved', '개인 사유', NOW());

-- 김희승 8월 11일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김희승', 'hee-seung.kim@hansl.com', 'annual', '2025-08-11', '2025-08-11', 'approved', '개인 사유', NOW());

-- 김희승 8월 18일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김희승', 'hee-seung.kim@hansl.com', 'half_am', '2025-08-18', '2025-08-18', 'approved', '개인 사유', NOW());

-- 김희승 8월 8일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김희승', 'hee-seung.kim@hansl.com', 'half_pm', '2025-08-08', '2025-08-08', 'approved', '개인 사유', NOW());

-- 곽병현 2월 28일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('곽병현', 'byeong-hyeon.kwak@hansl.com', 'annual', '2025-02-28', '2025-02-28', 'approved', '개인 사유', NOW());

-- 곽병현 8월 13일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('곽병현', 'byeong-hyeon.kwak@hansl.com', 'half_pm', '2025-08-13', '2025-08-13', 'approved', '개인 사유', NOW());

-- 윤은호 2월 14일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'eun-ho.yoon@hansl.com', 'half_pm', '2025-02-14', '2025-02-14', 'approved', '개인 사유', NOW());

-- 윤은호 3월 28일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'eun-ho.yoon@hansl.com', 'half_pm', '2025-03-28', '2025-03-28', 'approved', '개인 사유', NOW());

-- 윤은호 7월 14일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'eun-ho.yoon@hansl.com', 'annual', '2025-07-14', '2025-07-14', 'approved', '개인 사유', NOW());

-- 김윤회 4월 7일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김윤회', 'yoon-whoi.kim@hansl.com', 'annual', '2025-04-07', '2025-04-07', 'approved', '개인 사유', NOW());

-- 김윤회 4월 8일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김윤회', 'yoon-whoi.kim@hansl.com', 'annual', '2025-04-08', '2025-04-08', 'approved', '개인 사유', NOW());

-- 김윤회 4월 9일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김윤회', 'yoon-whoi.kim@hansl.com', 'annual', '2025-04-09', '2025-04-09', 'approved', '개인 사유', NOW());

-- 김윤회 4월 10일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김윤회', 'yoon-whoi.kim@hansl.com', 'annual', '2025-04-10', '2025-04-10', 'approved', '개인 사유', NOW());

-- 김윤회 4월 11일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김윤회', 'yoon-whoi.kim@hansl.com', 'annual', '2025-04-11', '2025-04-11', 'approved', '개인 사유', NOW());

-- 김윤회 4월 21일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김윤회', 'yoon-whoi.kim@hansl.com', 'annual', '2025-04-21', '2025-04-21', 'approved', '개인 사유', NOW());

-- 김윤회 8월 1일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김윤회', 'yoon-whoi.kim@hansl.com', 'half_pm', '2025-08-01', '2025-08-01', 'approved', '개인 사유', NOW());

-- 김윤회 8월 18일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('김윤회', 'yoon-whoi.kim@hansl.com', 'half_am', '2025-08-18', '2025-08-18', 'approved', '개인 사유', NOW());

-- 석진태 8월 5일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('석진태', 'jin-tae.seok@hansl.com', 'annual', '2025-08-05', '2025-08-05', 'approved', '개인 사유', NOW());

-- 여도근 2월 12일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('여도근', 'do-geun.yeo@hansl.com', 'half_am', '2025-02-12', '2025-02-12', 'approved', '개인 사유', NOW());

-- 여도근 7월 28일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('여도근', 'do-geun.yeo@hansl.com', 'annual', '2025-07-28', '2025-07-28', 'approved', '개인 사유', NOW());

-- 여도근 7월 9일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('여도근', 'do-geun.yeo@hansl.com', 'half_pm', '2025-07-09', '2025-07-09', 'approved', '개인 사유', NOW());

-- 강영은 2월 14일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('강영은', 'young-eun.kang@hansl.com', 'half_pm', '2025-02-14', '2025-02-14', 'approved', '개인 사유', NOW());

-- 강영은 3월 25일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('강영은', 'young-eun.kang@hansl.com', 'half_am', '2025-03-25', '2025-03-25', 'approved', '개인 사유', NOW());

-- 강영은 3월 25일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('강영은', 'young-eun.kang@hansl.com', 'half_pm', '2025-03-25', '2025-03-25', 'approved', '개인 사유', NOW());

-- 강영은 6월 18일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('강영은', 'young-eun.kang@hansl.com', 'half_am', '2025-06-18', '2025-06-18', 'approved', '개인 사유', NOW());

-- 강영은 6월 18일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('강영은', 'young-eun.kang@hansl.com', 'half_pm', '2025-06-18', '2025-06-18', 'approved', '개인 사유', NOW());

-- 강영은 7월 8일 오전 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('강영은', 'young-eun.kang@hansl.com', 'half_am', '2025-07-08', '2025-07-08', 'approved', '개인 사유', NOW());

-- 강영은 8월 18일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('강영은', 'young-eun.kang@hansl.com', 'annual', '2025-08-18', '2025-08-18', 'approved', '개인 사유', NOW());

-- 이한빈 2월 18일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이한빈', 'han-bin.lee@hansl.com', 'annual', '2025-02-18', '2025-02-18', 'approved', '개인 사유', NOW());

-- 이한빈 2월 17일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이한빈', 'han-bin.lee@hansl.com', 'half_pm', '2025-02-17', '2025-02-17', 'approved', '개인 사유', NOW());

-- 이한빈 7월 28일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이한빈', 'han-bin.lee@hansl.com', 'annual', '2025-07-28', '2025-07-28', 'approved', '개인 사유', NOW());

-- 이한빈 7월 29일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이한빈', 'han-bin.lee@hansl.com', 'annual', '2025-07-29', '2025-07-29', 'approved', '개인 사유', NOW());

-- 이한빈 8월 8일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이한빈', 'han-bin.lee@hansl.com', 'half_pm', '2025-08-08', '2025-08-08', 'approved', '개인 사유', NOW());

-- 백현덕 8월 4일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('백현덕', 'hyeon-deok.baek@hansl.com', 'annual', '2025-08-04', '2025-08-04', 'approved', '개인 사유', NOW());

-- 이종근 7월 21일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이종근', 'jong-geun.lee@hansl.com', 'annual', '2025-07-21', '2025-07-21', 'approved', '개인 사유', NOW());

-- 이종근 7월 28일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이종근', 'jong-geun.lee@hansl.com', 'annual', '2025-07-28', '2025-07-28', 'approved', '개인 사유', NOW());

-- 이종근 8월 18일 연차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이종근', 'jong-geun.lee@hansl.com', 'annual', '2025-08-18', '2025-08-18', 'approved', '개인 사유', NOW());

-- 이채령 8월 7일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('이채령', 'chae-ryeong.lee@hansl.com', 'half_pm', '2025-08-07', '2025-08-07', 'approved', '개인 사유', NOW());

-- 최창진 8월 14일 오후 반차 추가

INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('최창진', 'chang-jin.choi@hansl.com', 'half_pm', '2025-08-14', '2025-08-14', 'approved', '개인 사유', NOW());

-- 2. employees 테이블 사용연차/남은연차 업데이트
-- 양승진 사용연차 업데이트 (10.5일)

UPDATE employees 
SET used_annual_leave = 10.5,
    remaining_annual_leave = annual_leave_granted_current_year - 10.5
WHERE name = '양승진';

-- 최창열 사용연차 업데이트 (10일)

UPDATE employees 
SET used_annual_leave = 10,
    remaining_annual_leave = annual_leave_granted_current_year - 10
WHERE name = '최창열';

-- 김은정 사용연차 업데이트 (13.5일)

UPDATE employees 
SET used_annual_leave = 13.5,
    remaining_annual_leave = annual_leave_granted_current_year - 13.5
WHERE name = '김은정';

-- 이정화 사용연차 업데이트 (15.5일)

UPDATE employees 
SET used_annual_leave = 15.5,
    remaining_annual_leave = annual_leave_granted_current_year - 15.5
WHERE name = '이정화';

-- 하치복 사용연차 업데이트 (6.5일)

UPDATE employees 
SET used_annual_leave = 6.5,
    remaining_annual_leave = annual_leave_granted_current_year - 6.5
WHERE name = '하치복';

-- 김경태 사용연차 업데이트 (11일)

UPDATE employees 
SET used_annual_leave = 11,
    remaining_annual_leave = annual_leave_granted_current_year - 11
WHERE name = '김경태';

-- 조근일 사용연차 업데이트 (6.5일)

UPDATE employees 
SET used_annual_leave = 6.5,
    remaining_annual_leave = annual_leave_granted_current_year - 6.5
WHERE name = '조근일';

-- 이재형 사용연차 업데이트 (9.5일)

UPDATE employees 
SET used_annual_leave = 9.5,
    remaining_annual_leave = annual_leave_granted_current_year - 9.5
WHERE name = '이재형';

-- 임소연 사용연차 업데이트 (14.5일)

UPDATE employees 
SET used_annual_leave = 14.5,
    remaining_annual_leave = annual_leave_granted_current_year - 14.5
WHERE name = '임소연';

-- 김지혜 사용연차 업데이트 (7.5일)

UPDATE employees 
SET used_annual_leave = 7.5,
    remaining_annual_leave = annual_leave_granted_current_year - 7.5
WHERE name = '김지혜';

-- 정승후 사용연차 업데이트 (13.5일)

UPDATE employees 
SET used_annual_leave = 13.5,
    remaining_annual_leave = annual_leave_granted_current_year - 13.5
WHERE name = '정승후';

-- 나유성 사용연차 업데이트 (6.5일)

UPDATE employees 
SET used_annual_leave = 6.5,
    remaining_annual_leave = annual_leave_granted_current_year - 6.5
WHERE name = '나유성';

-- 정현웅 사용연차 업데이트 (1.5일)

UPDATE employees 
SET used_annual_leave = 1.5,
    remaining_annual_leave = annual_leave_granted_current_year - 1.5
WHERE name = '정현웅';

-- 정희웅 사용연차 업데이트 (10일)

UPDATE employees 
SET used_annual_leave = 10,
    remaining_annual_leave = annual_leave_granted_current_year - 10
WHERE name = '정희웅';

-- 김희승 사용연차 업데이트 (13.5일)

UPDATE employees 
SET used_annual_leave = 13.5,
    remaining_annual_leave = annual_leave_granted_current_year - 13.5
WHERE name = '김희승';

-- 곽병현 사용연차 업데이트 (10.5일)

UPDATE employees 
SET used_annual_leave = 10.5,
    remaining_annual_leave = annual_leave_granted_current_year - 10.5
WHERE name = '곽병현';

-- 윤은호 사용연차 업데이트 (10.5일)

UPDATE employees 
SET used_annual_leave = 10.5,
    remaining_annual_leave = annual_leave_granted_current_year - 10.5
WHERE name = '윤은호';

-- 김윤회 사용연차 업데이트 (14일)

UPDATE employees 
SET used_annual_leave = 14,
    remaining_annual_leave = annual_leave_granted_current_year - 14
WHERE name = '김윤회';

-- 석진태 사용연차 업데이트 (8일)

UPDATE employees 
SET used_annual_leave = 8,
    remaining_annual_leave = annual_leave_granted_current_year - 8
WHERE name = '석진태';

-- 여도근 사용연차 업데이트 (7일)

UPDATE employees 
SET used_annual_leave = 7,
    remaining_annual_leave = annual_leave_granted_current_year - 7
WHERE name = '여도근';

-- 강영은 사용연차 업데이트 (6일)

UPDATE employees 
SET used_annual_leave = 6,
    remaining_annual_leave = annual_leave_granted_current_year - 6
WHERE name = '강영은';

-- 이한빈 사용연차 업데이트 (8.5일)

UPDATE employees 
SET used_annual_leave = 8.5,
    remaining_annual_leave = annual_leave_granted_current_year - 8.5
WHERE name = '이한빈';

-- 백현덕 사용연차 업데이트 (5.5일)

UPDATE employees 
SET used_annual_leave = 5.5,
    remaining_annual_leave = annual_leave_granted_current_year - 5.5
WHERE name = '백현덕';

-- 이종근 사용연차 업데이트 (6일)

UPDATE employees 
SET used_annual_leave = 6,
    remaining_annual_leave = annual_leave_granted_current_year - 6
WHERE name = '이종근';

-- 이채령 사용연차 업데이트 (2일)

UPDATE employees 
SET used_annual_leave = 2,
    remaining_annual_leave = annual_leave_granted_current_year - 2
WHERE name = '이채령';

-- 최창진 사용연차 업데이트 (3일)

UPDATE employees 
SET used_annual_leave = 3,
    remaining_annual_leave = annual_leave_granted_current_year - 3
WHERE name = '최창진';

COMMIT;

-- 실행 후 확인 쿼리
-- SELECT name, COUNT(*) as count, SUM(CASE WHEN type = 'annual' THEN 1 WHEN type IN ('half_am', 'half_pm') THEN 0.5 END) as days
-- FROM leave 
-- WHERE status = 'approved' AND start_date >= '2025-01-01' AND start_date <= '2025-08-31'
-- GROUP BY name
-- ORDER BY name;
