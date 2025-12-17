# MAKE 이메일 템플릿 가이드

## 출장 승인 이메일 템플릿 수정 방법

### 현재 구조
- `reason`: 출장 시 **업무 내용(서술)** / 연차 시 **사유(서술)**
- `출장자` (TEXT[]): 출장자 + 동행자 전체 배열 (출장일 때만)
- `place`: 장소 (출장일 때만)
- `transport`: 교통수단 (출장일 때만)

### MAKE 템플릿 (권장)

```html
<div style="font-family:'Malgun Gothic','맑은 고딕',Apple SD Gothic Neo,Arial,sans-serif;font-size:15px;line-height:1.8;color:#222;">

  <p>안녕하세요. 한슬 {{3.record.name}} {{3.record.position}}입니다.</p>

  <p>하기 내용으로 {{6.`신청type`}} 공지합니다.</p>

  <p>
    <strong>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;일&nbsp;&nbsp;&nbsp;시 :</strong>&nbsp;&nbsp;{{formatDate(3.record.start_date; "MM/DD"; "Asia/Seoul")}}&nbsp;~&nbsp;{{formatDate(3.record.end_date; "MM/DD"; "Asia/Seoul")}}<br>
    <strong>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;신&nbsp;&nbsp;&nbsp;청&nbsp;&nbsp;&nbsp;자 :</strong>&nbsp;&nbsp;{{3.record.name}}<br>
    <strong>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;내&nbsp;&nbsp;&nbsp;용 :</strong>
  </p>
  
  {{#if 3.record.출장자}}
    <p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;출장자: {{join(3.record.출장자; ", ")}}<br></p>
  {{/if}}
  
  {{#if 3.record.place}}
    <p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;장소: {{3.record.place}}<br></p>
  {{/if}}
  
  {{#if 3.record.transport}}
    <p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;교통수단: {{3.record.transport}}<br></p>
  {{/if}}

  {{#if 3.record.reason}}
    <p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;업무: {{3.record.reason}}<br></p>
  {{/if}}

  <p>업무에 참고 바랍니다.</p>

  <p>이상입니다.</p>

<!-- 서명 시작 -->
<hr style="margin:24px 0;border:none;border-top:1px solid #ddd;">
<table cellpadding="0" cellspacing="0" border="0" width="500" style="border-collapse:collapse; font-family:Arial,'맑은 고딕','Malgun Gothic',sans-serif;">
  <tr>
    <td width="230" valign="middle" style="background-color:#1449b1;padding:10px;color:#fff;">
      <div style="font-size:15px;font-weight:bold;">Admin</div>
      <div style="font-size:12px;">Administrator</div>
    </td>
    <td width="230" valign="middle" style="background-color:#1d1d1d;padding:10px;color:#fff;text-align:right;">
      <div style="font-size:15px;font-weight:bold;">HANSL</div>
    </td>
  </tr>
  <tr><td colspan="2" style="height:8px;"></td></tr>
  <tr>
    <td colspan="2" style="background-color:#dddddd;padding:10px;color:#1d1d1d;font-size:12px;">
      <div>Mail: admin@hansl.com</div>
      <div>Phone: +82 53 626 7805 • Fax: +82 53 657 7905</div>
      <div><a href="http://www.hansl.com" style="color:#1d1d1d;text-decoration:none;">www.hansl.com</a></div>
    </td>
  </tr>
  <tr>
    <td colspan="2" style="padding-top:10px;color:#5d5d5d;font-size:10px;line-height:1.4;">
      HANSL • 305 Seongseogongdanbuk-ro Dalseo-gu • Daegu • 42703 • South Korea<br><br>
      This message is confidential. It may also be privileged or otherwise protected by work product immunity or other legal rules. 
      If you have received it by mistake, please let us know by e-mail reply and delete it from your system; 
      you may not copy this message or disclose its contents to anyone. Please send us by fax any message containing deadlines 
      as incoming e-mails are not screened for response deadlines. The integrity and security of this message cannot be guaranteed on the Internet.
    </td>
  </tr>
</table>
<!-- 서명 끝 -->
```

### MAKE에서 배열 필드 사용 방법

- `{{3.record.출장자}}` - 배열 전체를 문자열로 표시
- `{{join(3.record.출장자; ", ")}}` - 배열을 쉼표로 구분하여 표시 (권장)
- `{{3.record.출장자[0]}}` - 첫 번째 요소만 표시

### 확인 방법

1. MAKE 시나리오에서 "Supabase - Watch Events" 모듈을 확인하세요
2. 모듈 설정에서 "Columns to return" 필드가 비어있는지 확인하세요 (비어있으면 모든 컬럼 반환)
3. 테스트 실행 시 `3.record.출장자`, `3.record.place` 등의 필드가 보이는지 확인하세요

### 주의사항

- `출장자` 필드는 출장자 본인 + 동행자 전체를 포함한 배열입니다
- `reason` 필드는 출장 시 **업무 내용(서술)** 이 저장됩니다
- 새로 신청하는 출장부터는 자동으로 새 필드에 저장됩니다



