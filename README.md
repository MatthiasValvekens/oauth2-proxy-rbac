# oauth2-proxy-rbac

## Description

PoC for a utility chart that creates resources for integrating
RBAC with your ingress implementation of choice
(provided that it can deal with auth forwarding in a way that 
`oauth2-proxy` supports).

Currently, only Traefik is supported, but the configuration
is intended to be reusable.

The chart assumes `oauth2-proxy` to be present in the cluster already,
with configuration that supports auth forwarding.

## Basic usage

In your app chart, import the dependency with the appropriate defaults

```yaml
apiVersion: v2
name: my-application
description: A Helm chart for Kubernetes
dependencies:
  - name: oauth2-proxy-rbac
    repository: "oci://ghcr.io/matthiasvalvekens"
    version: "0.1.3"
    import-values:
      - traefikDefaults
      - oauth2ProxyDefaults

type: application
version: 0.1.0
appVersion: "1.16.0"
```

And in your `values.yaml`:

```yaml
oauth2Proxy:
  proxyNamespace: identity
  proxyServiceName: oauth2-proxy
authIngress:
  hosts:
    - host: example.com
      # these map onto the allowedGroups setting in oauth-proxy
      defaultAllowedRoles:
        - Foo
        - Bar
      defaultBackends:
        - name: backend
          port: 80
      routes:
        - prefix: /foo
          method: GET
        - prefix: /foo2
          method: POST
          allowedRoles:
            - Foo
        - prefix: /bar
          allowedRoles:
            - Foo
        - prefix: /baz
          headers:
            - name: "Content-Type"
              value: "application/json"
            - name: "X-Foo"
              value: "Bar"
          allowedRoles:
            - Foo
        - prefix: /baz
          allowedRoles:
            - Quux
        - prefix: /public
          anonymous: true
```

In order to generate all the resources required in one go
from the above config, add a template to your chart
with the following content.

```gotemplate
{{ include "oauth2-proxy-rbac.traefikAuthIngressRoute" . }}
---
{{ include "oauth2-proxy-rbac.traefikAllMiddlewares" . }}
```

If you want finer control over the way resources are generated,
you can reuse the subroutines invoked by these templates directly.