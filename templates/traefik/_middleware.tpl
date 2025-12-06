{{- define "oauth2-proxy-rbac.traefikMiddlewareBasePrefix" -}}
{{- if .middlewarePrefixOverride }}
{{- .middlewarePrefixOverride | trimSuffix "-" }}
{{- else if .create }}
{{- .fullname }}
{{- else -}}
oa2p
{{- end }}
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikMiddlewarePrefix" -}}
{{ include "oauth2-proxy-rbac.traefikMiddlewareBasePrefix" . }}-{{ include "oauth2-proxy-rbac.proxyUrlSlug" .proxy }}
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikAuthFwdMiddlewareName" -}}
{{- $args := dict "proxy" .traefikSettings.proxy "create" .traefikSettings.authFwdMiddleware.create "fullname" .traefikSettings.fullname }}
{{- include "oauth2-proxy-rbac.traefikMiddlewarePrefix" $args }}-auth-fwd-{{ include "oauth2-proxy-rbac.compositeRoleSlug" .allowedRoles }}
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikErrorsMiddlewareName" -}}
{{- if .errorMiddleware.name }}
{{- .errorMiddleware.name }}
{{- else }}
{{- $args := dict "proxy" .proxy "create" .errorMiddleware.create "fullname" .fullname }}
{{- include "oauth2-proxy-rbac.traefikMiddlewarePrefix" $args }}-errors
{{- end -}}
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikAuthHeadersMiddlewareName" -}}
{{- if .authHeaderMiddleware.name }}
{{- .authHeaderMiddleware.name }}
{{- else }}
{{- $args := dict "proxy" .proxy "create" .errorMiddleware.create "fullname" .fullname }}
{{- include "oauth2-proxy-rbac.traefikMiddlewarePrefix" $args }}-auth-headers
{{- end -}}
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikOAuth2ProxyService" -}}
name: {{ .proxyServiceName }}
port: {{ .proxyPort }}
{{- if .proxyNamespace }}
namespace: {{ .proxyNamespace }}
{{- end }}
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikAuthFwdMiddleware" }}
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: {{ include "oauth2-proxy-rbac.traefikAuthFwdMiddlewareName" . }}
spec:
  forwardAuth:
    {{- $args := dict "proxy" .traefikSettings.proxy "allowedRoles" .allowedRoles }}
    address: {{ include "oauth2-proxy-rbac.authForwardWithGroupsUrl" $args }}
    {{- with .traefikSettings.authFwdMiddleware.extraSettings}}
    {{ toYaml . | nindent 4 }}
    {{- end }}
{{- end }}

{{- define "oauth2-proxy-rbac.traefikErrorsMiddlewareRender" }}
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: {{ include "oauth2-proxy-rbac.traefikErrorsMiddlewareName" . }}
  {{- if .authHeaderMiddleware.namespace }}
  namespace: {{ .authHeaderMiddleware.namespace }}
  {{- end }}
spec:
  errors:
    {{ .errorMiddleware.settings | toYaml | nindent 4}}
    {{- if not (hasKey .errorMiddleware.settings "service")}}
    service:
      {{- include "oauth2-proxy-rbac.traefikOAuth2ProxyService" .proxy | nindent 6 }}
    {{- end }}
{{- end }}

{{- define "oauth2-proxy-rbac.traefikAuthHeadersMiddlewareRender" }}
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: {{ include "oauth2-proxy-rbac.traefikAuthHeadersMiddlewareName" . }}
  {{- if .authHeaderMiddleware.namespace }}
  namespace: {{ .authHeaderMiddleware.namespace }}
  {{- end }}
spec:
  headers:
    {{ .authHeaderMiddleware.headers | toYaml | nindent 4}}
{{- end }}

{{- define "oauth2-proxy-rbac.traefikMiddlewaresForRoutes" }}
  {{ $global := dict "traefikSettings" .traefikSettings }}
  {{ $todo := dict }}
  {{- range $host := .hosts }}
    {{- if $host.defaultAllowedRoles }}
      {{ $args := merge (dict "allowedRoles" $host.defaultAllowedRoles) $global }}
      {{ $name := include "oauth2-proxy-rbac.traefikAuthFwdMiddlewareName" $args }}
      {{ $data := include "oauth2-proxy-rbac.traefikAuthFwdMiddleware" $args }}
      {{ $_ := set $todo $name $data }}
    {{- end }}
    {{- range $route := .routes }}
      {{- if $route.allowedRoles }}
        {{ $args := merge (dict "allowedRoles" $route.allowedRoles) $global }}
        {{ $name := include "oauth2-proxy-rbac.traefikAuthFwdMiddlewareName" $args }}
        {{ $data := include "oauth2-proxy-rbac.traefikAuthFwdMiddleware" $args }}
        {{ $_ := set $todo $name $data }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- range $k := keys $todo | uniq | sortAlpha }}
    {{- get $todo $k }}
    {{- print "\n---" }}
  {{- end }}
{{- end }}

{{- define "oauth2-proxy-rbac.traefikErrorsMiddleware" }}
{{ $name := include "oauth2-proxy-rbac.fullname" . }}
{{ $proxy := .Values.oauth2Proxy }}
{{- with .Values.authIngress.traefikSettings }}
{{ $args := merge . (dict "proxy" $proxy "fullname" $name) }}
{{- include "oauth2-proxy-rbac.traefikErrorsMiddlewareRender" $args }}
{{- end }}
{{- end }}

{{- define "oauth2-proxy-rbac.traefikAuthHeadersMiddleware" }}
{{ $name := include "oauth2-proxy-rbac.fullname" . }}
{{ $proxy := .Values.oauth2Proxy }}
{{- with .Values.authIngress.traefikSettings }}
{{ $args := merge . (dict "proxy" $proxy "fullname" $name) }}
{{- include "oauth2-proxy-rbac.traefikAuthHeadersMiddlewareRender" $args }}
{{- end }}
{{- end }}

{{- define "oauth2-proxy-rbac.traefikAllAuthFwdMiddlewares" }}
{{ $name := include "oauth2-proxy-rbac.fullname" . }}
{{ $global := merge .Values.authIngress.traefikSettings (dict "proxy" .Values.oauth2Proxy "fullname" $name) }}
{{ mergeOverwrite .Values.authIngress (dict "traefikSettings" $global) | include "oauth2-proxy-rbac.traefikMiddlewaresForRoutes" | trim }}
{{- end }}

{{- define "oauth2-proxy-rbac.traefikAllMiddlewares" }}
{{- $settings := .Values.authIngress.traefikSettings }}
{{- if and $settings.errorMiddleware.create $settings.errorMiddleware.enabled }}
{{- include "oauth2-proxy-rbac.traefikErrorsMiddleware" . }}
---
{{- end }}
{{- if and $settings.authHeaderMiddleware.create $settings.authHeaderMiddleware.enabled }}
{{- include "oauth2-proxy-rbac.traefikAuthHeadersMiddleware" . }}
---
{{- end }}
{{- if and $settings.authFwdMiddleware.create }}
{{- include "oauth2-proxy-rbac.traefikAllAuthFwdMiddlewares" . }}
---
{{- end }}
{{- end }}
