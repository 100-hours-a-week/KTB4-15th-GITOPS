{{/* Labels shared by namespace-level policy resources. */}}
{{- define "lookddak-domain.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: lookddak
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
