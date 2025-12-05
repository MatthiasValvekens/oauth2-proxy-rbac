
{{- define "oauth2-proxy-rbac.traefikAuthRouteMatchHeaders" }}
{{ $lst := list }}
{{ range $hdr := .headers }}
{{ $lst := append $lst (printf "Header(`%s`, `%s`)" $hdr.name $hdr.value) }}
{{ end }}
{{ join " && " $lst }}
{{- end }}

{{- define "oauth2-proxy-rbac.traefikAuthRouteMatch" -}}
{{- $host := ternary "" (printf "Host(`%s`)" .router.host) (empty .router.host) -}}
{{- $prefix := ternary "" (printf "PathPrefix(`%s`)" .prefix) (empty .prefix) -}}
{{- $method := ternary "" (printf "Method(`%s`)" .method) (empty .method) -}}
{{- $headers := include "oauth2-proxy-rbac.traefikAuthRouteMatchHeaders" . | trim -}}
{{- without (list $host $prefix $method $headers) "" | join " && " -}}
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikAuthenticatedRoute" }}
- kind: Rule
  match: {{ include "oauth2-proxy-rbac.traefikAuthRouteMatch" . }}
  {{- if .priority }}
  priority: {{ .priority }}
  {{- end }}
  services:
    {{- toYaml .backends | nindent 4 }}
  middlewares:
    {{- if .ingressRouteGlobals.errorMiddleware.enabled }}
    - name: {{ include "oauth2-proxy-rbac.traefikErrorsMiddlewareName" . }}
      {{- if .ingressRouteGlobals.errorMiddleware.inProxyNamespace }}
      namespace: {{ .ingressRouteGlobals.proxy.proxyNamespace }}
      {{- end }}
    {{- end }}
    - name: {{ include "oauth2-proxy-rbac.traefikAuthFwdMiddlewareName" . }}
{{- end }}

{{- define "oauth2-proxy-rbac.traefikAuthenticatedRoutes" }}
{{ $global := dict "router" . "ingressRouteGlobals" .ingressRouteGlobals "allowedRoles" .defaultAllowedRoles "backends" .defaultBackends }}
{{- if .routes }}
    {{- range $route := .routes }}
        {{ $augRoute := merge $route $global }}
        {{ include "oauth2-proxy-rbac.traefikAuthenticatedRoute" $augRoute }}
    {{- end }}
{{- else }}
    {{- /*
    Emit a route that matches all traffic for the host
    */}}
    {{ include "oauth2-proxy-rbac.traefikAuthenticatedRoute" $global }}
{{- end }}
{{- if .ingressRouteGlobals.routeOAuth2Prefix }}
- match: {{ printf "Host(`%s`)" .host }} && PathPrefix(`/oauth2/`)
  middlewares:
    {{- if .ingressRouteGlobals.authHeaderMiddleware.enabled }}
    - name: {{ include "oauth2-proxy-rbac.traefikAuthHeadersMiddlewareName" . }}
      {{- if .ingressRouteGlobals.authHeaderMiddleware.inProxyNamespace }}
      namespace: {{ .ingressRouteGlobals.proxy.proxyNamespace }}
      {{- end }}
    {{- end }}
  services:
    - name: {{ .ingressRouteGlobals.proxy.proxyServiceName }}
      port: {{ .ingressRouteGlobals.proxy.proxyPort }}
      {{- if .ingressRouteGlobals.proxy.proxyNamespace }}
      namespace: {{ .ingressRouteGlobals.proxy.proxyNamespace }}
      {{- end }}
{{- end }}
{{- end -}}

# authIngress:
#   tls: ...
#   hosts:
#     - host: ...
#       defaultAllowedRoles: 
#       defaultBackends:
#       routes:
#         - prefix: ...
#           method: ...
{{- define "oauth2-proxy-rbac.traefikAuthIngressRouteSpec" }}
entryPoints:
  - websecure
tls:
  {{ toYaml .tls | nindent 2 }}
routes:
  {{ $global := dict "ingressRouteGlobals" .ingressRouteGlobals }}
  {{ range $host := .hosts }}
      {{ merge $host $global | include "oauth2-proxy-rbac.traefikAuthenticatedRoutes" | nindent 2 }}
  {{ end }}
{{- end }}


{{- define "oauth2-proxy-rbac.traefikAuthIngressRoute" }}
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: {{ include "oauth2-proxy-rbac.fullname" . }}
  labels:
    {{- include "oauth2-proxy-rbac.labels" . | nindent 4 }}
  {{- with .Values.authIngress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{ $global := merge .Values.ingressRouteDefaults (dict "proxy" .Values.oauth2ProxyDefaults) }}
  {{ merge .Values.authIngress (dict "ingressRouteGlobals" $global) | include "oauth2-proxy-rbac.traefikAuthIngressRouteSpec" | trim | nindent 2 }}
{{- end }}
