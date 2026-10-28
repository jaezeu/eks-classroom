# Cluster Add-ons

Helm-based add-ons installed on top of a provisioned EKS cluster. Each
directory is self-contained: a `values.yaml` (Helm configuration) and an
`init.sh` (adds the Helm repo and installs/upgrades the release). The
`init.sh` scripts are invoked by the bootstrap job in the
[cluster creation workflows](../.github/workflows), gated by per-add-on toggles.

## Add-ons at a glance

| Add-on | Namespace | Chart | Version | Purpose |
|--------|-----------|-------|---------|---------|
| [argocd](argocd/) | `argocd` | argo/argo-cd | 10.11.6 | GitOps continuous delivery |
| [cert-manager](cert-manager/) | `cert-manager` | jetstack/cert-manager | v1.21.3 | TLS certificates (Let's Encrypt) |
| [nginx-ingress](nginx-ingress/) | `ingress-nginx` | ingress-nginx/ingress-nginx | 4.15.1 | HTTP(S) ingress |
| [r53-externaldns](r53-externaldns/) | `external-dns` | external-dns/external-dns | 1.23.0 | Route 53 DNS automation |
| [kube-prometheus-stack](kube-prometheus-stack/) | `monitoring` | prometheus-community/kube-prometheus-stack | 92.14.1 | Prometheus, Grafana, Alertmanager |
| [loki](loki/) | `loki` | grafana/loki (+ promtail) | 6.55.0 | Log aggregation (S3 backend) |
| [opentelemetry-demo](opentelemetry-demo/) | `otel-demo` | open-telemetry/opentelemetry-demo | 0.42.6 | Astronomy shop on the Cilium workflow. Uses this Prometheus, Grafana, Loki, and Jaeger. Selects m6g.xlarge. |
| [ebs-csi-driver](ebs-csi-driver/) | `kube-system` | aws-ebs-csi-driver | 2.67.2 | EBS volumes; default StorageClass `gp3` |
| [metrics-server](metrics-server/) | `kube-system` | metrics-server/metrics-server | 3.14.0 | `kubectl top` and HorizontalPodAutoscaler metrics |
| [keda](keda/) | `monitoring` | kedacore/keda | 2.21.0 | Event-driven autoscaling |
| [kyverno](kyverno/) | `kyverno` | kyverno/kyverno | 3.9.2 | Admission controller + [guardrail policies](../kyverno-policies/) |
| [kyverno](kyverno/) (Policy Reporter) | `kyverno` | policy-reporter/policy-reporter | 3.11.2 | Kyverno PolicyReport UI; installed by `kyverno/init.sh` |
| [trivy-operator](trivy-operator/) | `trivy-system` | aqua/trivy-operator | 0.37.0 | Workload vulnerability and config-audit reports |
| [cilium](cilium/) | `kube-system` | cilium/cilium | 1.20.4 | eBPF CNI, Hubble, Gateway API + ListenerSet (Cilium clusters) |
| [cilium/tetragon](cilium/tetragon/) | `kube-system` | cilium/tetragon | 1.7.1 | eBPF runtime security (Cilium clusters) |

> **Cilium** is a special case: its `values.yaml`/`init.sh` live here, but it is
> installed by the [Cilium cluster workflow](../.github/workflows/create-cilium-cluster.yml)
> **before node groups join** (between the two Terraform applies), not by the
> bootstrap job. See [cilium/](cilium/) for the Gateway API resources, and
> the [Cilium architecture diagram](../docs/images/cilium-architecture.png).

## Standard vs Gateway API variants

Add-ons exposed over HTTP(S) carry two full config files: the default
`values.yaml` (nginx Ingress, standard cluster) and a `gateway-*` variant
(Gateway API, Cilium cluster). Each `init.sh` defaults to `values.yaml`; the
Cilium workflow passes the variant explicitly (e.g. `./init.sh gateway-values.yaml`).

| Add-on | Gateway API files |
|--------|-------------------|
| cert-manager | `gateway-values.yaml` (ListenerSet reconciliation on) + `gateway-cluster-issuer.yaml` (`letsencrypt-gateway`, HTTP-01 via `gatewayHTTPRoute`) |
| r53-externaldns | `gateway-values.yaml` (`gateway-httproute` source, ListenerSet resolution) |
| argocd | `gateway-values.yaml` (ingress off, insecure server) + `gateway-route.yaml` (ListenerSet + HTTPRoute) |
| kube-prometheus-stack | `gateway-values.yaml` (ingress off) + `gateway-route.yaml` (ListenerSet + 2 HTTPRoutes) |
| kyverno (Policy Reporter) | `policy-reporter-gateway-values.yaml` (ingress off) + `policy-reporter-gateway-route.yaml` (ListenerSet + HTTPRoute), selected with `./init.sh gateway` |

On the Cilium cluster the workflow creates one shared entrypoint,
[`cilium/gateway/shared-gateway.yml`](cilium/gateway/shared-gateway.yml): a
Gateway owning only the `:80` listener (ACME challenges + plain HTTP) with
`allowedListeners: All`. Every app then self-serves its HTTPS listener, cert
and route with a ListenerSet + HTTPRoute in its own namespace. That includes
[Hubble UI](cilium/gateway/hubble-ui-route.yaml), which the workflow exposes
alongside the shared Gateway. See
[deployment-manifests-examples/gateway-api-coaching](../deployment-manifests-examples/gateway-api-coaching/)
for the student-facing walkthrough. Hostnames are guarded by the
[Gateway API Kyverno policy](../kyverno-policies/gateway-api/) on Cilium
clusters, mirroring `restrict-ingress-hosts` on standard ones.

## Install order & dependencies

Order matters, since several add-ons consume resources created by others:

1. **nginx-ingress**: provisions the load balancer other UIs are exposed through.
2. **external-dns**: needs its [IRSA role](../terraform/eks-cluster/irsa.tf) (Route 53); publishes records for Ingress hosts.
3. **cert-manager**: install the chart, then apply the [`ClusterIssuer`](cert-manager/cluster-issuer.yaml). Other add-ons reference it via `cert-manager.io/cluster-issuer` annotations.
4. **argocd**, **kube-prometheus-stack**: expose Ingress hosts (depend on 1-3 for DNS + TLS).
5. **loki**: needs its IRSA role and the two S3 buckets created by Terraform (`enable_loki_s3`).
6. **tetragon**: Cilium clusters only; ships ServiceMonitors scraped by Prometheus (install after monitoring).
7. **ebs-csi-driver**: needs its IRSA role. It also installs the default `gp3` StorageClass, so anything that asks for a volume can bind one.
8. **metrics-server**: `kube-system` already exists, so the namespace-name policy does not apply. Gives `kubectl top` and the HorizontalPodAutoscaler API. **KEDA** installs into the `monitoring` namespace (shared with Prometheus when that is selected).
9. **trivy-operator**, then **kyverno**: Trivy is first because the namespace-name policy would reject `trivy-system`. Kyverno is last among namespace-creating installs. Its [policies](../kyverno-policies/) enforce namespace naming and block deletions in protected namespaces. The same `init.sh` then installs Policy Reporter into the existing `kyverno` namespace (a new namespace would be rejected), where the PolicyReport CRDs it needs already exist.
10. **opentelemetry-demo**: Cilium workflow only, after Prometheus and Loki, and before Kyverno. The namespace-name policy would reject `otel-demo`. Selecting it creates the node group as `m6g.xlarge`.

Add-on charts that expose metrics ship a ServiceMonitor (`ingress-nginx`,
`external-dns`, `cert-manager`, `argo-cd`, Cilium/Hubble, EBS CSI, Loki,
Promtail, Kyverno, Metrics Server, KEDA, Policy Reporter, Tetragon, Trivy Operator).
Both cluster workflows run
[`kube-prometheus-stack/install-crds.sh`](kube-prometheus-stack/install-crds.sh)
once before the first add-on. It applies the Prometheus Operator CRDs from
kube-prometheus-stack `92.14.1` (the same pin as `init.sh`; Renovate updates
both) when they are not already installed, so the
monitors can be created before the monitoring stack itself. Running an
`init.sh` by hand on a cluster without those CRDs needs that script first.
The stack selects every ServiceMonitor
(`serviceMonitorSelectorNilUsesHelmValues: false`).

Grafana files the add-ons that cluster installs into folders when its pod
starts ([`kube-prometheus-stack/dashboards-values.yaml`](kube-prometheus-stack/dashboards-values.yaml)).
The chart's own Kubernetes dashboards go in **Admin**. Both clusters get
**Network** (external-dns, and the demo's NGINX board), **Security**
(cert-manager, Kyverno, Trivy Operator), and **DevOps** (Argo CD, Loki,
Promtail, and the demo's application boards). The demo's Linux board goes in
**Admin** with the node dashboards. The standard cluster also gets the
ingress-nginx dashboards; the Cilium cluster gets Cilium, Hubble, and
Tetragon instead. The download runs from the Grafana init container, so the
pod needs outbound access to grafana.com and GitHub, and a failed fetch stops
Grafana from starting.

## Network policy

Every add-on chart was checked for a network-policy switch. Chart defaults
leave the switch off. Where a switch exists it is turned on, with rules that
cover the traffic that component actually sends and receives. An enabled
policy with an empty rule list denies that direction, so the values set the
allows explicitly wherever the chart default would drop traffic.

Cilium evaluates both `cilium.io/v2 CiliumNetworkPolicy` and
`networking.k8s.io/v1 NetworkPolicy`. Policies that select the same pods are a
union of allows. On the Cilium cluster, a chart that has a `flavor: cilium`
switch uses CiliumNetworkPolicy. Every other chart uses Kubernetes
NetworkPolicy, including on the Cilium cluster. The standard cluster uses
Kubernetes NetworkPolicy for every chart that has the switch.

The Cilium agent runs in audit mode (`policyAuditMode: true` in
[`cilium/values.yaml`](cilium/values.yaml)). It still computes the verdict for
every selected pod and records it, and it allows the packet.
`policyEnforcementMode` stays at the chart default, `default`, so a pod with
no policy selecting it is left open. The standard cluster's VPC CNI does not
enforce NetworkPolicy unless that feature is enabled on the addon, so those
objects are installed and not applied there.

| Component | Chart switch | Cilium cluster | Standard cluster |
|-----------|--------------|----------------|------------------|
| Prometheus | `prometheus.networkPolicy` (`flavor`) | CiliumNetworkPolicy | NetworkPolicy |
| Prometheus Operator | `prometheusOperator.networkPolicy` (`flavor`) | CiliumNetworkPolicy | NetworkPolicy |
| kube-state-metrics | `kube-state-metrics.networkPolicy` | NetworkPolicy | NetworkPolicy |
| Loki | `networkPolicy` (`flavor`) | CiliumNetworkPolicy | NetworkPolicy |
| KEDA (operator, metrics apiserver, webhooks) | `networkPolicy` (`flavor`) | CiliumNetworkPolicy | NetworkPolicy |
| Alertmanager | `alertmanager.networkPolicy` | NetworkPolicy | NetworkPolicy |
| Grafana | `grafana.networkPolicy` | NetworkPolicy | NetworkPolicy |
| node-exporter | `prometheus-node-exporter.networkPolicy` | NetworkPolicy | NetworkPolicy |
| Promtail | `networkPolicy` | NetworkPolicy | NetworkPolicy |
| cert-manager, webhook, cainjector | `networkPolicy` on each | NetworkPolicy | NetworkPolicy |
| Kyverno (four controllers) | `<controller>.networkPolicy` | NetworkPolicy | NetworkPolicy |
| Argo CD | `global.networkPolicy.create` | NetworkPolicy | NetworkPolicy |
| ingress-nginx | `controller.networkPolicy` | not installed | NetworkPolicy |
| Policy Reporter core and Kyverno plugin | `networkPolicy` | NetworkPolicy | NetworkPolicy |
| Policy Reporter UI | chart policy left off (empty `from`) | — | — |
| external-dns 1.23.0 | none | — | — |
| EBS CSI driver 2.67.2 | none | — | — |
| Metrics Server 3.14.0 | none | — | — |
| Trivy Operator 0.37.0 | none | — | — |
| Tetragon 1.7.1 | none | — | — |
| OpenTelemetry demo | CiliumNetworkPolicy manifests | CiliumNetworkPolicy | not installed |

Cilium itself is the policy engine and is not wrapped in a default-deny
policy. external-dns, the EBS CSI driver, Metrics Server, Trivy Operator, and
Tetragon stay unrestricted because their charts have no policy key to enable.

### kube-prometheus-stack

**Prometheus.** The Kubernetes template always sets policy types Ingress and
Egress. Empty lists deny both directions, which would stop scrapes and
queries. The standard values set both to allow-all: Prometheus scrapes every
ServiceMonitor, including kubelet and the hostNetwork node-exporter on node
IPs, and Grafana and the ingress query it. The Cilium template renders only
when `cilium` is set, and an empty `cilium` block selects the pods but writes
no rules. The gateway values set egress `toEntities` `cluster` (pod targets
and CoreDNS), `host` and `remote-node` (kubelet and node-exporter), and
`kube-apiserver` (the EKS API). Ingress is ports 9090 and 8080 with no source
selector, so probes, Grafana, and the Cilium gateway can connect.

**Prometheus Operator.** Chart 92.14.1 serves the operator over TLS on port
10250 (`--web.listen-address=:10250`). Probes are HTTPS `GET /healthz` on
that port. The Kubernetes policy allows port 10250 from any source and allows
all egress, which covers probes, scrapes, the API, and DNS. The Cilium
template's default egress is only `kube-apiserver`. Setting `cilium.egress`
replaces that list, so the gateway values include `kube-apiserver` and DNS
(`k8s:io.kubernetes.pod.namespace=kube-system`, `k8s:k8s-app=kube-dns`, port
53). Ingress is port 10250 with no L7 filter, because TLS is enabled and the
chart omits the HTTP path rule in that case. The admission create/patch jobs
reuse the same egress list. They only talk to the API.

**kube-state-metrics.** The Kubernetes template always sets both policy
types. With egress unset, every outbound connection is denied and the API
watch fails. Egress is TCP 443 (EKS API) plus DNS 53 TCP and UDP. Liveness
uses the `http` port (8080). Readiness uses the `metrics` port (8081). The
chart adds 8081 to the policy only when `selfMonitor.enabled` is true, so
that is turned on for both clusters. The kube-state-metrics subchart (8.x
since kube-prometheus-stack 92) no longer has a Cilium flavor, so both
clusters use the same Kubernetes egress list; Cilium enforces it. Ingress is
ports 8080 and 8081 with no source selector.

**Alertmanager.** Kubernetes NetworkPolicy only. The default policy type is
Ingress, so notifications, DNS, and clustering egress stay open. Default
ingress allows Prometheus on 9093 and the reloader port 8080. The chart's
peer rule is emitted only when `service.clusterPort` is set; it is unset
here and the install is a single replica. `additionalIngress` opens 9093 and
8080 with no source selector, so probes, Grafana, the Loki ruler,
ingress-nginx, and cilium-envoy can all reach it.

**Grafana.** Kubernetes NetworkPolicy only. Ingress stays at the chart
default (`allowExternal: true`) on container port 3000, so the ingress, the
Cilium gateway, and probes can open the UI. Egress is enabled and limited to
the chart's DNS rule plus TCP 80, 443, 8080, 9090, 9093, and 16686. Those are
Prometheus (9090), Alertmanager (9093), the Loki gateway (service port 80,
container port 8080), Jaeger (16686), and 443 for the dashboard download. The download runs
in the Grafana pod, so a 443 deny stops Grafana from starting.

**node-exporter.** Ingress allows port 9100 from any source. The policy type
list includes Egress and the chart writes no egress rules, so outbound
traffic is denied. The exporter reads the node locally and does not open
connections. It runs with `hostNetwork: true`; Prometheus reaches it through
the host and remote-node entities on the Cilium Prometheus policy, and
through the allow-all egress on the standard Prometheus policy.

### KEDA

Chart `2.21.0`, release `keda`, namespace `monitoring`. `networkPolicy.enabled`
is set and `networkPolicy.flavor` is `kubernetes` in `values.yaml`. The Cilium
workflow runs `./init.sh cilium`, which merges
[`networkpolicy-cilium.yaml`](keda/networkpolicy-cilium.yaml) and switches the
flavor. The chart renders one flavor or the other. `certificates.certManager`
stays off, so the chart's self-signed webhook certificates are used and
cert-manager is not required.

Prometheus metrics are on for the operator, the metrics apiserver, and the
admission webhooks (`prometheus.operator.enabled`,
`prometheus.metricServer.enabled`, `prometheus.webhooks.enabled`), each with
a ServiceMonitor in `monitoring`. The scrape port on every component is 8080,
named `metrics`.

The chart's Kubernetes rules, once enabled:

- DNS UDP and TCP 53 to pods labeled `k8s-app: kube-dns`. CoreDNS in
  `kube-system` matches. The selector is any namespace.
- Egress to every pod, with no port list, so the operator can reach
  in-cluster metric sources such as Prometheus. The metrics apiserver can
  reach the operator gRPC port 9666.
- TCP 443 and 6443 to every pod. That does not reach the EKS API, which is
  not a pod and listens on 443. `extraEgressRules` on the operator, the
  metrics apiserver, and the webhooks adds TCP 443 with no destination peer.
  Kubernetes NetworkPolicy cannot select that endpoint. The rule is not an
  `ipBlock` of `0.0.0.0/0`, and it does allow 443 to any address, which is
  what makes the API reachable. 6443 is not added.
- Ingress from any pod on 9666 (operator gRPC), 6443 (metrics apiserver
  HTTPS), and 9443 (admission webhook). Port 8080 is added on each
  component because Prometheus metrics are enabled.

Those ingress rules select pods. The API server and the kubelet are not pods,
and the chart omits probe port 8081. Three extra Kubernetes NetworkPolicies
in `values.yaml` apply on both clusters. Each is Ingress only and has no
`from` selector:

- `keda-operator-ingress`: TCP 8081 (probes, `/healthz` and `/readyz`) and
  TCP 8080 (Prometheus).
- `keda-metrics-apiserver-ingress`: TCP 6443 (API aggregation for
  `external.metrics.k8s.io`, and the HTTPS probes) and TCP 8080.
- `keda-admission-webhooks-ingress`: TCP 9443 (admission), TCP 8081 (probes),
  and TCP 8080.

The Cilium template replaces the chart's Kubernetes policies. Egress is
`toEntities` `kube-apiserver` and `cluster`. `cluster` covers in-cluster
metric sources and CoreDNS, so UDP and TCP 53 to `kube-system` are allowed
without a separate DNS rule and without world egress. The `extraEgressRules`
443 rule is not rendered on this flavor. Ingress is `fromEntities` `cluster`,
which covers Prometheus and the gRPC call from the metrics apiserver, and
does not cover the API server or the kubelet. The extra policies above supply
those ports.

### Loki and Promtail

Loki's chart has `flavor: kubernetes` and `flavor: cilium`. `loki-values.yaml`
enables the Kubernetes policy and is what the standard workflow installs. The
Cilium workflow runs `./init.sh cilium`, which merges
[`networkpolicy-cilium.yaml`](loki/networkpolicy-cilium.yaml) and switches
the flavor. MinIO's subchart has the same switch; `minio.enabled` is false,
so it is not rendered.

The chart's own rules, once enabled:

- Same-namespace traffic. On Kubernetes this is `podSelector: {}` limited to
  the `loki` namespace. On Cilium the chart selects `toEndpoints` /
  `fromEndpoints` `{}`, which matches every endpoint in the cluster.
- DNS UDP 53 for pods labeled `app.kubernetes.io/name: loki`.
- Metrics port `http-metrics` from any source.
- Gateway ingress on port `http-metrics`. The gateway container and Service
  both name that port `http-metrics` (container 8080, Service 80). The
  Cilium template also emits a port named `http`, which this gateway does
  not have; the metrics rule is the one that opens the real port.
- Alertmanager egress on 9093, selecting `app.kubernetes.io/component: backend`.
  This install is `deploymentMode: Distributed` with `backend.replicas: 0`,
  so that selector matches nothing. The ruler
  (`app.kubernetes.io/component: ruler`) is the process that posts to
  `http://kube-prometheus-stack-alertmanager.monitoring:9093`.
- External storage TCP 443 with no CIDR, for every Loki-labeled pod. That
  covers S3 and the EKS API. The chart's `egressKubeApiserver` rule only
  selects the backend target, so it is left off. `egressWorld` is left off;
  it only covers read, write, and backend, and it opens all world egress.

Three extra Kubernetes NetworkPolicies in `loki-values.yaml` apply on both
clusters. Cilium enforces them alongside the Cilium policies:

- `loki-ruler-alertmanager`: ruler egress to Alertmanager in `monitoring` on
  TCP 9093. Alertmanager's ingress allows that port.
- `loki-dns-all`: every pod in the namespace (canary, memcached, Promtail)
  to CoreDNS in `kube-system` on UDP and TCP 53. The chart DNS rule only
  selects Loki's own labels.
- `loki-ingress-monitoring`: every pod in the namespace accepts ingress from
  the `monitoring` namespace, so Prometheus can scrape canary and the caches
  and Grafana can query the gateway.
- `loki-ingress-otel-demo`: the gateway accepts TCP 8080 from the `otel-demo`
  namespace, so the collector can push OTLP logs.

Promtail has no Cilium flavor. Its policy allows same-namespace traffic
(the push to the Loki gateway), DNS, metrics from any source, and the
Kubernetes API. The chart default API port is 8443; EKS serves the API on
443, so `networkPolicy.k8sApi.port` is 443. Log files are read from the
node, not over the kubelet port. The same-namespace rule uses
`podSelector: {}`, which also selects the Loki pods. It adds an allow and
does not remove the Loki, DNS, or 443 allows.

### OpenTelemetry demo

Chart `0.42.6`. The demo Prometheus, Grafana, and OpenSearch subcharts are
off. The collector DaemonSet pushes metrics with OTLP to the in-cluster
Prometheus (`enableOTLPReceiver`, with the same promoted resource attributes
as the demo Prometheus) and pushes logs to
`http://loki-gateway.loki.svc.cluster.local/otlp`. Jaeger stays in the demo
namespace. Grafana gets a Jaeger datasource only when this add-on is applied,
and Prometheus stores exemplars (`exemplar-storage`).

The Cilium workflow is the only one that offers this add-on. Selecting it
passes `node_instance_types=["m6g.xlarge"]` to Terraform. The chart dashboards
are loaded with the Prometheus uid set to `prometheus` and the Jaeger uid set
to `jaeger`. Linux is filed in **Admin**, image-provider NGINX in **Network**,
and cart exemplars, spanmetrics, the demo board, APM, the collector, and
PostgreSQL in **DevOps**.
OpenSearch log panels are LogQL on the demo board and dropped where the panel
was OpenSearch-only. The quote panel filtered `job="quote"` and is removed.
PostgreSQL queries `k8s_deployment_name` because astronomy-db is a Deployment.

`init.sh` applies [`networkpolicy.yaml`](opentelemetry-demo/networkpolicy.yaml).
The shop components have no policy switch. The collector subchart can emit a
Kubernetes NetworkPolicy only, and that object cannot select the EKS API or
the kubelet. Jaeger accepts `networkPolicy.enabled` and chart 0.42.6 does not
render a policy from it. The manifests are CiliumNetworkPolicy:

- Every pod may talk to every other pod in `otel-demo`, and to CoreDNS on
  UDP and TCP 53. Kubelet probes are allowed from the `host` entity, and
  Cilium's health checks from the `health` entity.
- The collector (`app.kubernetes.io/name=opentelemetry-collector`) may also
  reach `cluster`, `host`, `remote-node`, and `kube-apiserver`. That covers
  annotation discovery, the Prometheus OTLP receiver, the Loki gateway,
  kubelet stats, and the Kubernetes attribute receiver. Prometheus already
  accepts 9090 from any source, and the Loki gateway already accepts 8080
  from `otel-demo`.
- Jaeger may open TCP 9090 in `monitoring` (its `PROMETHEUS_ADDR`). Grafana
  may open Jaeger TCP 16686; Grafana's own egress list already includes that
  port.
- The agent talks to a recorded VCR cassette (`USE_VCR=true`), so there is
  no world egress. frontend-proxy still names a `grafana` service in
  `otel-demo`; the demo Grafana subchart is off, and no cross-namespace
  allow is added for that name.

### cert-manager

`networkPolicy`, `webhook.networkPolicy`, and `cainjector.networkPolicy` are
enabled in both `values.yaml` and `gateway-values.yaml`. The chart defaults
are kept. Ingress allows the metrics, health, and webhook ports from any
source, so the API server can call the webhook and Prometheus can scrape.
Egress allows 80, 443, 53, and 6443 to any destination. The EKS API is on
443, so that port covers the API, ACME, and AWS. ACME solver pods are
created in other namespaces and are not selected by these policies.

### Kyverno

`networkPolicy.enabled` is set on the admission, background, cleanup, and
reports controllers. `ingressFrom` is left empty. The template treats an
empty list as unset and writes `ingress: [{}]` with policy type Ingress
only, so egress stays open. That lets the API server call the webhooks and
lets Prometheus scrape. A namespace selector would not match the API server,
which is the webhook client.

### Policy Reporter

Installed by `kyverno/init.sh` after the guardrail policies, into the
`kyverno` namespace, from `kyverno/policy-reporter-values.yaml` or the
`policy-reporter-gateway-values.yaml` variant. The chart's default
egress opens only TCP 6443. Both values files replace that with TCP 443 (the
EKS API) and DNS on 53, for the core process and the Kyverno plugin. Ingress
on 8080 has no source selector, so probes, Prometheus, the UI, nginx, and
cilium-envoy can connect.

The UI policy stays off. The chart always writes an ingress rule with an
empty `from`, and the API rejects that object. The UI pod is therefore not
selected by a policy, so its egress stays open and the ingress or gateway
can reach it.

The chart's Grafana dashboards stay off too. They reference an unresolved
datasource input, so the sidecar would mount panels with no datasource. The
Kyverno dashboards already filed under Security cover the admission
controller. Metrics stay on, and Prometheus scrapes the ServiceMonitor.

### Argo CD

`global.networkPolicy.create` is set in both values files.
`defaultDenyIngress` is left false; that flag renders a deny-all ingress
policy. The chart policies are Ingress only, so egress stays open for git,
Helm, the API, and the identity provider.

- **server:** ingress from any source, so nginx or cilium-envoy and probes can reach the UI.
- **controller, notifications, applicationSet:** metrics port from any namespace. Probes use that port.
- **repo-server:** server, controller, notifications, and applicationSet on the repo-server port, plus metrics from any namespace.
- **redis:** server, repo-server, and controller on the redis port, plus metrics. Probes are exec probes.
- **dex:** the server on the http and grpc ports, plus metrics.

### ingress-nginx

Enabled only in `addons/nginx-ingress/values.yaml`. The Cilium cluster does
not install this chart. Ingress allows the controller ports (80, 443), the
metrics port (10254), and the admission webhook port (8443) from any source.
Egress is allow-all, so the controller can reach every backend and the API.
The certgen job's own policy stays off; cert-manager issues the webhook
certificate.

### IRSA-dependent add-ons

These rely on IAM Roles for Service Accounts created by
[`terraform/eks-cluster/irsa.tf`](../terraform/eks-cluster/irsa.tf):

| Add-on | Service account | AWS access |
|--------|-----------------|------------|
| external-dns | `external-dns` | Route 53 records |
| loki | `loki` | S3 (chunks + ruler buckets) |
| ebs-csi-driver | `ebs-csi-controller-sa` | EBS volume lifecycle |

## Manual install

Each add-on can be installed on its own once `kubectl`/`helm` are pointed at the
cluster. Some `init.sh` scripts expect environment variables (e.g.
`$EXTERNAL_DNS_ROLE_ARN`, `$CLUSTER_NAME`, `$REGION`) substituted into the
values file:

```bash
cd addons/<addon>
# review values.yaml, then:
./init.sh
```
