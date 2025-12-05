{{- define "oauth2-proxy-rbac.proxyBaseUrl" }}
{{ $nsSuffix := ternary "" (printf ".%s" .proxyNamespace) (empty .proxyNamespace) }}
{{- if and (eq .proxyScheme "http") (eq (int .proxyPort) 80) }}
http://{{ .proxyService }}{{ $nsSuffix }}
{{- else if and (eq .proxyScheme "https") (eq (int .proxyPort) 443) }}
https://{{ .proxyService }}{{ $nsSuffix }}
{{- else }}
{{ .proxyScheme }}://{{ .proxyService }}{{ $nsSuffix }}:{{ int .proxyPort }}
{{- end }}
{{- end }}

{{- define "oauth2-proxy-rbac.authForwardWithGroupsUrl" }}
{{ include "oauth2-proxy-rbac.proxyBaseUrl" .proxy }}/oauth2/auth?allowed_groups={{ join "," .allowedRoles }}
{{- end }}

{{- define "oauth2-proxy-rbac.compositeRoleSlug" -}}
{{ if . }}{{ sortAlpha . | join "," | sha256sum | trunc 7 }}{{ else }}{{ fail "empty role list is forbidden!" }}{{ end }}
{{- end -}}

{{- define "oauth2-proxy-rbac.proxyUrlSlug" -}}
{{ include "oauth2-proxy-rbac.proxyBaseUrl" . | trim | sha256sum | trunc 7 }}
{{- end -}}

