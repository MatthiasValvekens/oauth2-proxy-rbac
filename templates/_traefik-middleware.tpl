{{- define "oauth2-proxy-rbac.traefikMiddlewarePrefix" -}}
{{ .traefikSettings.middlewarePrefix }}-{{ include "oauth2-proxy-rbac.proxyUrlSlug" .traefikSettings.proxy }}
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikAuthFwdMiddlewareName" -}}
{{ include "oauth2-proxy-rbac.traefikMiddlewarePrefix" . }}-auth-fwd-{{ include "oauth2-proxy-rbac.compositeRoleSlug" .allowedRoles }}
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikErrorsMiddlewareName" -}}
{{ include "oauth2-proxy-rbac.traefikMiddlewarePrefix" . }}-errors
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikAuthHeadersMiddlewareName" -}}
{{ include "oauth2-proxy-rbac.traefikMiddlewarePrefix" . }}-auth-headers
{{- end -}}

{{- define "oauth2-proxy-rbac.traefikAuthFwdMiddleware" }}
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: {{ include "oauth2-proxy-rbac.traefikAuthFwdMiddlewareName" . }}
spec:
  forwardAuth:
    address: {{ include "oauth2-proxy-rbac.authForwardWithGroupsUrl" . }}
    trustForwardHeader: true
{{- end }}

