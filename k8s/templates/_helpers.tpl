{{/* vim: set filetype=mustache: */}}
{{/*
Define common labels
*/}}
{{- define "birthday-tekken-api.labels" -}}
app: birthday-api
app.kubernetes.io/name: birthday-tekken-api
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Define a consistent app name
*/}}
{{- define "birthday-tekken-api.name" -}}
birthday-api
{{- end -}}
