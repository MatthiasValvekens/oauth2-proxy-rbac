
{{/*
Generate the prefix used for naming Gateway API auth filter resources.
Input: dict with keys: proxy, middlewarePrefixOverride, fullname
*/}}
{{- define "oauth2-proxy-rbac.gatewayFilterPrefix" -}}
{{- if .middlewarePrefixOverride -}}
{{- .middlewarePrefixOverride | trimSuffix "-" -}}
{{- else -}}
{{- .fullname -}}
{{- end -}}
-{{ include "oauth2-proxy-rbac.proxyUrlSlug" .proxy | trim }}
{{- end -}}

{{/*
Generate the name of the auth forward ExtensionRef resource for a given role set.
Input: dict with keys: gatewaySettings (proxy, middlewarePrefixOverride, fullname), allowedRoles
*/}}
{{- define "oauth2-proxy-rbac.gatewayAuthFwdFilterName" -}}
{{- include "oauth2-proxy-rbac.gatewayFilterPrefix" .gatewaySettings | trim }}-auth-fwd-{{ include "oauth2-proxy-rbac.compositeRoleSlug" .allowedRoles | trim }}
{{- end -}}

{{/*
Generate a single HTTPRouteMatch object.
Input: dict with keys:
  - prefix: path prefix string (optional, defaults to /)
  - method: HTTP method string (optional)
  - headers: list of {name, value} dicts (optional)
*/}}
{{- define "oauth2-proxy-rbac.gatewayRouteMatch" -}}
- path:
    type: PathPrefix
    value: {{ default "/" .prefix | quote }}
  {{- if .method }}
  method: {{ .method | upper | quote }}
  {{- end }}
  {{- if .headers }}
  headers:
    {{- range .headers }}
    - name: {{ .name | quote }}
      value: {{ .value | quote }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Generate a single HTTPRoute rule.
Input: route dict merged with host-level defaults, plus gatewaySettings
*/}}
{{- define "oauth2-proxy-rbac.gatewayAuthenticatedRouteRule" }}
- matches:
    {{- include "oauth2-proxy-rbac.gatewayRouteMatch" . | nindent 4 }}
  {{- if not .anonymous }}
  filters:
    - type: ExtensionRef
      extensionRef:
        group: {{ .gatewaySettings.authFwdFilter.extensionRef.group | quote }}
        kind: {{ .gatewaySettings.authFwdFilter.extensionRef.kind | quote }}
        name: {{ include "oauth2-proxy-rbac.gatewayAuthFwdFilterName" . | trim | quote }}
  {{- end }}
  backendRefs:
    {{- range .backends }}
    - name: {{ .name | quote }}
      port: {{ .port }}
      {{- if .namespace }}
      namespace: {{ .namespace | quote }}
      {{- end }}
    {{- end }}
{{- end -}}

{{/*
Generate all HTTPRoute rules for a single host.
Input: host dict merged with global authIngress, including gatewaySettings
*/}}
{{- define "oauth2-proxy-rbac.gatewayAuthenticatedRouteRules" -}}
{{- $global := dict "gatewaySettings" .gatewaySettings "allowedRoles" .defaultAllowedRoles "backends" .defaultBackends }}
{{- if .routes }}
  {{- range $route := .routes }}
    {{- $augRoute := merge $route $global }}
    {{- include "oauth2-proxy-rbac.gatewayAuthenticatedRouteRule" $augRoute }}
  {{- end }}
{{- else }}
  {{- include "oauth2-proxy-rbac.gatewayAuthenticatedRouteRule" $global }}
{{- end }}
{{- if .gatewaySettings.routeOAuth2Prefix }}
- matches:
    - path:
        type: PathPrefix
        value: "/oauth2/"
  {{- if .gatewaySettings.authHeaderFilter.enabled }}
  filters:
    - type: ResponseHeaderModifier
      responseHeaderModifier:
        set:
          {{- range $name, $value := .gatewaySettings.authHeaderFilter.headers }}
          - name: {{ $name | quote }}
            value: {{ $value | quote }}
          {{- end }}
  {{- end }}
  backendRefs:
    - name: {{ .gatewaySettings.proxy.proxyServiceName | quote }}
      port: {{ .gatewaySettings.proxy.proxyPort }}
      {{- if .gatewaySettings.proxy.proxyNamespace }}
      namespace: {{ .gatewaySettings.proxy.proxyNamespace | quote }}
      {{- end }}
{{- end }}
{{- end -}}

{{/*
Entry point: generate all HTTPRoute resources (one per host).
Invoked from the consumer chart's template.
*/}}
{{- define "oauth2-proxy-rbac.gatewayAllAuthHTTPRoutes" -}}
{{- $name := include "oauth2-proxy-rbac.fullname" . -}}
{{- $root := . -}}
{{- $gatewaySettings := merge .Values.authIngress.gatewaySettings (dict "proxy" .Values.oauth2Proxy "fullname" $name) -}}
{{- $global := mergeOverwrite .Values.authIngress (dict "gatewaySettings" $gatewaySettings) -}}
{{- range $host := $global.hosts }}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ printf "%s-%s" $name ($host.host | replace "." "-" | replace "*" "wildcard") | trunc 63 | trimSuffix "-" }}
  labels:
    {{- include "oauth2-proxy-rbac.labels" $root | nindent 4 }}
  {{- with $global.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  parentRefs:
    {{- toYaml $gatewaySettings.parentRefs | nindent 4 }}
  hostnames:
    - {{ $host.host | quote }}
  rules:
    {{- merge $host $global | include "oauth2-proxy-rbac.gatewayAuthenticatedRouteRules" | nindent 4 }}
---
{{- end -}}
{{- end -}}
