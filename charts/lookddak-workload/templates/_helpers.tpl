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
