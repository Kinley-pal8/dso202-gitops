{{- /*
=============================================================================
File        : charts/tasktracker/templates/_helpers.tpl
Assignment  : DSO202 Assignment 4
Descriptor  : Unit III 3.2 - Helm named templates
Purpose     : Named templates shared by every file in templates/.

Object names are fixed (db, backend, frontend) rather than
"<release>-<chart>": the backend reaches its database at the host "db", and
the release name is fixed to "tasktracker" in both Applications anyway. The
namespace is what separates dev from staging.
=============================================================================
*/}}

{{/* tasktracker.environment: the environment name, or a render failure. */}}
{{- define "tasktracker.environment" -}}
{{- required "environment must be set: pass -f environments/<env>/values.yaml" .Values.environment }}
{{- end }}

{{/* tasktracker.secretName: the credentials Secret (C3), or a render failure. */}}
{{- define "tasktracker.secretName" -}}
{{- required "existingSecret must be set: the chart never renders a Secret" .Values.existingSecret }}
{{- end }}

{{/* tasktracker.chart: "<name>-<version>", for the helm.sh/chart label. */}}
{{- define "tasktracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* tasktracker.commonLabels: labels shared by every object. */}}
{{- define "tasktracker.commonLabels" -}}
helm.sh/chart: {{ include "tasktracker.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
dso202/environment: {{ include "tasktracker.environment" . | quote }}
app: task-tracker
{{- end }}

{{/*
tasktracker.selectorLabels: what Services and workloads select on. Selectors
are immutable, so nothing that changes between releases may appear here.
Usage: include "tasktracker.selectorLabels" (list . "backend")
*/}}
{{- define "tasktracker.selectorLabels" -}}
{{- $root := index . 0 -}}
app.kubernetes.io/name: {{ $root.Chart.Name }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
tier: {{ index . 1 }}
{{- end }}

{{/* tasktracker.labels: full label set for a tiered object. Usage as above. */}}
{{- define "tasktracker.labels" -}}
{{- $root := index . 0 -}}
{{ include "tasktracker.commonLabels" $root }}
tier: {{ index . 1 }}
{{- end }}

{{/*
tasktracker.wave: the Argo CD sync-wave annotation for one tier (C5).
database "0", backend "1", frontend "2". Argo CD applies a wave only when the
previous one is Healthy, so the database is ready before the backend starts,
and the backend before the frontend. Helm ignores the annotation.
Usage: include "tasktracker.wave" "backend"
*/}}
{{- define "tasktracker.wave" -}}
{{- $waves := dict "database" "0" "backend" "1" "frontend" "2" -}}
argocd.argoproj.io/sync-wave: {{ get $waves . | quote }}
{{- end }}

{{/*
tasktracker.configChecksum: a hash of the values that feed one tier's
ConfigMap, put on that tier's Pod template so that a changed setting rolls
those Pods (a ConfigMap read through envFrom is only read at start-up).
The database name and port are included because they feed db-config and
backend-config alike. Usage: include "tasktracker.configChecksum" (list . "backend")
*/}}
{{- define "tasktracker.configChecksum" -}}
{{- $root := index . 0 -}}
{{- $tier := get $root.Values (index . 1) -}}
{{- list $root.Values.database.name $root.Values.database.port $tier.config | toJson | sha256sum }}
{{- end }}
