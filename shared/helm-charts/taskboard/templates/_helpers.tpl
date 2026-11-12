{{- define "taskboard.name" -}}taskboard{{- end -}}

{{- define "taskboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "taskboard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "taskboard.labels" -}}
{{ include "taskboard.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.version | quote }}
app.kubernetes.io/part-of: devops-sre-engineering-labs
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "taskboard.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- $digest := required "image.digest is required (deploy by digest: sha256:...)" .Values.image.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}
