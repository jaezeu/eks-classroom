# cert-manager

Deploy after the ingress layer and ExternalDNS, since the ClusterIssuers
solve ACME HTTP-01 challenges through them.

`init.sh` installs the chart and applies the ClusterIssuer. It defaults to the
standard-cluster files; the Cilium workflow passes the Gateway API variants:

```bash
./init.sh                                            # standard: values.yaml + cluster-issuer.yaml (nginx solver)
./init.sh gateway-values.yaml gateway-cluster-issuer.yaml   # Cilium: gatewayHTTPRoute solver
```

The issuer files contain two placeholders that `init.sh` fills with `envsubst`
from its environment before applying:

- `${EMAIL}`: the ACME registration email. Required; the workflows pass the
  `EMAIL_ADDRESS` secret.
- `${ACME_SERVER}`: the Let's Encrypt directory URL. Defaults to production.
  The workflows' `staging-certs` input switches it to the staging directory,
  which the monthly rehearsal uses so it never consumes the production quota
  of 5 duplicate certificates per week per hostname set. Staging certificates
  are not browser-trusted, so the verify job curls with `-k` in that mode.

For a manual install, export both (or just `EMAIL`) before running `init.sh`.
