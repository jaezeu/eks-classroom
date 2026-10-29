"""Detailed platform overview for the EKS platform.

Shows the VPC/subnet layout, the EKS control plane and its managed add-ons,
the ARM64 managed node group, every in-cluster add-on grouped by namespace,
the Kyverno admission layer, and the IRSA roles that
map Kubernetes service accounts to AWS services (Route 53 / S3 / EBS).

Regenerate:  python3 platform_overview.py   ->  ../images/platform-overview.png
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EKS, EC2
from diagrams.aws.network import VPC, PublicSubnet, PrivateSubnet, NATGateway, InternetGateway, ELB, Route53
from diagrams.aws.security import IAMRole
from diagrams.aws.storage import S3, ElasticBlockStoreEBS
from diagrams.k8s.compute import DaemonSet, Deployment
from diagrams.k8s.controlplane import KubeProxy
from diagrams.k8s.network import Ingress, Service
from diagrams.k8s.others import CRD
from diagrams.k8s.podconfig import CM
from diagrams.onprem.gitops import ArgoCD
from diagrams.onprem.monitoring import Prometheus, Grafana
from diagrams.onprem.logging import Loki
from diagrams.onprem.aggregator import Vector
from diagrams.onprem.network import Nginx
from diagrams.onprem.dns import Coredns
from diagrams.custom import Custom

graph_attr = {
    "fontsize": "22",
    "labelloc": "t",
    "bgcolor": "white",
    "pad": "0.7",
    "nodesep": "0.5",
    "ranksep": "1.1",
    "compound": "true",
}

import os
_ICON_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
ICON = lambda n: os.path.join(_ICON_DIR, f"{n}.png")

with Diagram(
    "EKS Platform — Detailed Architecture",
    filename="../images/platform-overview",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
):
    # --- External AWS services reached via IRSA ---
    route53 = Route53("Route 53\nhosted zone\n*.sctp-sandbox.com")
    s3 = S3("S3 buckets\nloki-chunks /\nloki-ruler")
    ebs = ElasticBlockStoreEBS("EBS volumes")

    with Cluster("AWS Account  (eu / ap region)"):

        with Cluster("VPC  172.31.0.0/16  (2 AZs)"):
            igw = InternetGateway("Internet\nGateway")

            with Cluster("Public subnets\n172.31.101-102.0/24"):
                nat = NATGateway("NAT GW\n(single)")
                nlb = ELB("NLB / ELB\n(ingress + loki gw)")

            with Cluster("Private subnets  172.31.1-2.0/24"):

                with Cluster("EKS Cluster  v1.36  (OIDC / IRSA enabled)"):
                    cp = EKS("Control Plane\npublic endpoint")

                    with Cluster("EKS-managed add-ons"):
                        cp_addons = [
                            Coredns("CoreDNS"),
                            EC2("pod-identity\nagent"),
                            KubeProxy("kube-proxy\n(standard only)"),
                        ]

                    with Cluster("Managed Node Group\n3-5x m6g.large  (AL2023 ARM64)"):
                        nodes = [EC2("node"), EC2("node"), EC2("node")]

                    # ---- in-cluster add-ons grouped by namespace ----
                    with Cluster("ns: kube-system"):
                        cilium = Custom("Cilium agent\n(eBPF, cilium mode)", ICON("cilium"))
                        tetragon = Custom("Tetragon\nruntime security", ICON("tetragon"))
                        ebs_csi = DaemonSet("ebs-csi\ndriver")

                    with Cluster("ns: ingress-nginx"):
                        nginx = Nginx("NGINX\nIngress Controller")

                    with Cluster("ns: cert-manager"):
                        certmgr = Custom("cert-manager\n+ ClusterIssuer\n(Let's Encrypt)", ICON("certmanager"))

                    with Cluster("ns: external-dns"):
                        extdns = Custom("ExternalDNS\n(policy: sync)", ICON("externaldns"))

                    with Cluster("ns: argocd"):
                        argo = ArgoCD("Argo CD")

                    with Cluster("ns: monitoring"):
                        prom = Prometheus("Prometheus\n+ Alertmanager")
                        graf = Grafana("Grafana")

                    with Cluster("ns: loki"):
                        loki = Loki("Loki\n(distributed, S3)")
                        vector = Vector("Vector\n(DaemonSet)")

                    with Cluster("ns: kyverno"):
                        kyverno = Custom("Kyverno\nadmission policies", ICON("kyverno"))

    # ---- traffic path ----
    igw >> nat
    igw >> Edge(label="HTTPS") >> nlb >> nginx
    nginx >> Edge(color="darkblue") >> [argo, graf, prom]
    cp >> nodes

    # ---- observability scrape ----
    [tetragon, cilium] >> Edge(style="dotted", color="gray40", label="ServiceMonitor") >> prom
    prom >> Edge(color="orange") >> graf
    vector >> Edge(label="logs") >> loki
    loki >> Edge(color="orange") >> graf

    # ---- TLS + DNS automation ----
    certmgr >> Edge(style="dashed", color="purple", label="certs") >> nginx
    extdns >> Edge(style="dashed", color="darkgreen", label="A / CNAME records") >> route53

    # ---- IRSA -> AWS ----
    irsa = IAMRole("IRSA roles\n(OIDC-trusted)")
    cp >> Edge(style="bold", color="firebrick") >> irsa
    irsa >> Edge(color="firebrick", label="route53:*") >> route53
    irsa >> Edge(color="firebrick", label="s3:*") >> s3
    irsa >> Edge(color="firebrick", label="ebs csi") >> ebs
    loki >> Edge(style="dotted", color="firebrick") >> s3
