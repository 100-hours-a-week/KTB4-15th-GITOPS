{{/* 워크로드 이름을 결정한다. */}}
{{- define "lookddak-workload.name" -}}
{{- required "workload.name is required" .Values.workload.name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* 워크로드 선택자에서 사용하는 고정 라벨이다. */}}
{{- define "lookddak-workload.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lookddak-workload.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* 이 차트가 생성하는 모든 리소스의 공통 라벨이다. */}}
{{- define "lookddak-workload.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "lookddak-workload.selectorLabels" . }}
app.kubernetes.io/component: {{ include "lookddak-workload.name" . }}
app.kubernetes.io/part-of: lookddak
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.workload.runtimeRole }}
lookddak.io/runtime-role: {{ .Values.workload.runtimeRole | quote }}
{{- end }}
{{- end }}

{{/* 공통 이미지 그룹을 변경할 수 없는 ECR 이미지 주소로 변환한다. */}}
{{- define "lookddak-workload.image" -}}
{{- $groupName := required "imageGroup is required" .Values.imageGroup -}}
{{- $group := index .Values.images $groupName -}}
{{- if not $group -}}
{{- fail (printf "images.%s is not defined" $groupName) -}}
{{- end -}}
{{- $repository := required (printf "images.%s.repository is required" $groupName) $group.repository -}}
{{- $digest := required (printf "images.%s.digest is required" $groupName) $group.digest -}}
{{- printf "%s@%s" $repository $digest -}}
{{- end }}

{{/* 명시한 값, 차트가 생성한 값 또는 기본값으로 서비스 계정 이름을 결정한다. */}}
{{- define "lookddak-workload.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else if .Values.serviceAccount.create -}}
{{- include "lookddak-workload.name" . -}}
{{- else -}}
default
{{- end -}}
{{- end }}

{{/* Secret 시작 스크립트 ConfigMap 이름을 결정한다. */}}
{{- define "lookddak-workload.secretStartupConfigMapName" -}}
{{- printf "%s-secret-startup" (include "lookddak-workload.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Secret 시작 기능의 필수 값과 안전한 환경변수·파일 이름을 검증한다. */}}
{{- define "lookddak-workload.validateSecretStartup" -}}
{{- if .Values.secrets.startup.enabled -}}
  {{- if not .Values.secrets.enabled -}}
    {{- fail "secrets.enabled must be true when secrets.startup.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.secrets.startup.environment -}}
    {{- fail "secrets.startup.environment is required when Secret startup is enabled" -}}
  {{- end -}}
  {{- if not .Values.secrets.startup.command -}}
    {{- fail "secrets.startup.command is required when Secret startup is enabled" -}}
  {{- end -}}
  {{- $_ := required "secrets.startup.scriptMountPath is required when Secret startup is enabled" .Values.secrets.startup.scriptMountPath -}}
  {{- range .Values.secrets.startup.environment -}}
    {{- $name := required "secrets.startup.environment[].name is required" .name -}}
    {{- $fileName := required "secrets.startup.environment[].fileName is required" .fileName -}}
    {{- if not (regexMatch "^[A-Za-z_][A-Za-z0-9_]*$" $name) -}}
      {{- fail (printf "invalid Secret environment variable name: %s" $name) -}}
    {{- end -}}
    {{- if not (regexMatch "^[A-Za-z0-9._-]+$" $fileName) -}}
      {{- fail (printf "invalid Secret file name: %s" $fileName) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}
