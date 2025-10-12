#!/usr/bin/env python3
import json
import time
import jwt
import requests

# Firebase 서비스 계정 키 파일 읽기
with open('/Users/scott/workspace/hansl/hansl-attendance-firebase-adminsdk.json', 'r') as f:
    service_account = json.load(f)

# JWT 페이로드 생성
now = int(time.time())
payload = {
    'iss': service_account['client_email'],
    'sub': service_account['client_email'],
    'aud': 'https://oauth2.googleapis.com/token',
    'scope': 'https://www.googleapis.com/auth/firebase.messaging',
    'iat': now,
    'exp': now + 3600
}

# JWT 생성
encoded_jwt = jwt.encode(
    payload,
    service_account['private_key'],
    algorithm='RS256'
)

print(f"JWT 생성 완료: {encoded_jwt[:50]}...")
print(f"JWT 길이: {len(encoded_jwt)}")

# OAuth2 토큰 요청
response = requests.post(
    'https://oauth2.googleapis.com/token',
    headers={'Content-Type': 'application/x-www-form-urlencoded'},
    data={
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': encoded_jwt
    }
)

print(f"\nOAuth2 응답 상태: {response.status_code}")
print(f"응답: {response.text}")

if response.status_code == 200:
    token_data = response.json()
    access_token = token_data['access_token']
    
    # FCM 테스트
    fcm_response = requests.post(
        'https://fcm.googleapis.com/v1/projects/hansl-attendance/messages:send',
        headers={
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        },
        json={
            'message': {
                'token': 'f23Fx1dZaO1oUYCZezD4CS:APA91bHAlsqXxvjvK3zw9pkZTYipSPRwW9DcZBnrrX8LuZ545AlRnPFQ_8Qx0lIXQpKKh5cUiIMavaUKT2Trw60iOtGlZzNv36b3kyMk5oBf2DIgXxB5bPc',
                'notification': {
                    'title': '🎉 Python 테스트',
                    'body': 'Python에서 보낸 푸시 알림'
                }
            }
        }
    )
    
    print(f"\nFCM 응답 상태: {fcm_response.status_code}")
    print(f"FCM 응답: {fcm_response.text}")