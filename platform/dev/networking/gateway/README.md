# Istio Gateway — dev

## 목적

dev의 공용 Istio Gateway와 Gateway API 설정을 GitOps로 관리하기 위한 디렉터리다.

## 확정된 요청 흐름

`CloudFront + WAF → Internal NLB → Istio Gateway → HTTPRoute → Service`

## 미결정 항목

- Gateway와 GatewayClass 이름
- Gateway Namespace와 Listener 이름
- TLS 인증서와 TLS 종료 위치
- NLB Annotation과 Target 설정
- SSE Timeout 값

네트워크 담당자와 공용 Gateway 식별자를 합의한 후 각 워크로드의 HTTPRoute가 이를 참조하도록 구성한다.
