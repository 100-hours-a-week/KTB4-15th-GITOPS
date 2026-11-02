{{/* Resolve the workload name. */}}
{{- define "lookddak-workload.name" -}}
{{- required "workload.name is required" .Values.workload.name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Stable labels used by workload selectors. */}}
{{- define "lookddak-workload.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lookddak-workload.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Labels shared by all resources created by this chart. */}}
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

{{/* Resolve a shared image group to an immutable ECR image reference. */}}
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

{{/* Resolve an explicit, chart-created, or default ServiceAccount name. */}}
{{- define "lookddak-workload.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else if .Values.serviceAccount.create -}}
{{- include "lookddak-workload.name" . -}}
{{- else -}}
default
{{- end -}}
{{- end }}
