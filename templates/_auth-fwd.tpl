{{- define "oauth2-proxy-rbac.proxyBaseUrl" }}
{{- $nsSuffix := ternary "" (printf ".%s" .proxyNamespace) (empty .proxyNamespace) }}
{{- if and (eq .proxyScheme "http") (eq (int .proxyPort) 80) }}
http://{{ .proxyServiceName }}{{ $nsSuffix }}
{{- else if and (eq .proxyScheme "https") (eq (int .proxyPort) 443) }}
https://{{ .proxyServiceName }}{{ $nsSuffix }}
{{- else }}
{{- .proxyScheme }}://{{ .proxyServiceName }}{{ $nsSuffix }}:{{ int .proxyPort }}
{{- end }}
{{- end }}

{{- define "oauth2-proxy-rbac.authForwardWithGroupsUrl" -}}
{{- include "oauth2-proxy-rbac.proxyBaseUrl" .proxy | trim }}/oauth2/auth?allowed_groups={{ join "," .allowedRoles }}
{{- end -}}

{{- define "oauth2-proxy-rbac.compositeRoleSlug" -}}
{{ if . }}{{ sortAlpha . | join "," | sha256sum | trunc 7 }}{{ else }}{{ fail "empty role list is forbidden!" }}{{ end }}
{{- end -}}

{{- define "oauth2-proxy-rbac.proxyUrlSlug" -}}
{{ include "oauth2-proxy-rbac.proxyBaseUrl" . | trim | sha256sum | trunc 7 }}
{{- end -}}

