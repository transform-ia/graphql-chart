{{/*
Expand the name of the chart.
*/}}
{{- define "graphql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "graphql.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "graphql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "graphql.labels" -}}
helm.sh/chart: {{ include "graphql.chart" . }}
{{ include "graphql.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "graphql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "graphql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: graphql-dev
{{- end }}

{{/*
Namespace
*/}}
{{- define "graphql.namespace" -}}
{{- .Values.global.namespace | default "graphql-dev" }}
{{- end }}

{{/*
Service Account Name
*/}}
{{- define "graphql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default "graphql-dev" .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "graphql.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets }}
{{- range .Values.global.imagePullSecrets }}
- name: {{ .name }}
{{- end }}
{{- end }}
{{- end }}

{{/*
PostgreSQL data database name
*/}}
{{- define "graphql.dataDatabaseName" -}}
{{- .Values.postgresql.dataDatabase | default .Release.Name }}
{{- end }}

{{/*
PostgreSQL metadata database name
*/}}
{{- define "graphql.metadataDatabaseName" -}}
{{- .Values.postgresql.metadataDatabase | default (printf "%s-hasura" .Release.Name) }}
{{- end }}

{{/*
PostgreSQL connection URL for Hasura
*/}}
{{- define "graphql.databaseURL" -}}
{{- $user := .Values.postgresql.user }}
{{- $password := .Values.postgresql.password }}
{{- $host := printf "%s.%s.svc.cluster.local" .Values.postgresql.service (include "graphql.namespace" .) }}
{{- $port := .Values.postgresql.port | toString }}
{{- $database := include "graphql.dataDatabaseName" . }}
{{- printf "postgres://%s:%s@%s:%s/%s" $user $password $host $port $database }}
{{- end }}
