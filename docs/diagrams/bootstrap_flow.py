"""Detailed cluster bootstrap flow for both GitHub Actions workflows.

Two lanes reflecting the real workflow steps:
  - create-standard-cluster.yml : single terraform apply (VPC CNI + kube-proxy
    + nodes), then Helm add-on bootstrap.
  - create-cilium-cluster.yml   : split apply (cluster only -> install Gateway
    API CRDs + Cilium 1.19.3 -> apply again to add nodes), then add-ons.

Regenerate:  python3 bootstrap_flow.py  ->  ../images/bootstrap-flow.png
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EKS, EC2
from diagrams.aws.security import IAMRole
from diagrams.k8s.others import CRD
from diagrams.k8s.compute import Pod
from diagrams.onprem.iac import Terraform
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.network import Nginx
from diagrams.custom import Custom

graph_attr = {
    "fontsize": "22",
    "labelloc": "t",
    "bgcolor": "white",
    "pad": "0.7",
    "ranksep": "0.8",
    "splines": "ortho",
}
import os
_ICON_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
ICON = lambda n: os.path.join(_ICON_DIR, f"{n}.png")

with Diagram(
    "Cluster Bootstrap Flow — Standard vs Cilium",
    filename="../images/bootstrap-flow",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
):
    gha = GithubActions("GitHub Actions\nOIDC -> deployer role")

    with Cluster("Prereq (run once)"):
        role = IAMRole("create-deployer-role.yml\nIAM role for CI")

    # ---------------- Standard lane ----------------
    with Cluster("create-standard-cluster.yml   (workspace: standard-cluster)"):
        s_tf = Terraform("terraform apply\n(defaults)")
        s_eks = EKS("EKS + VPC + IRSA\n+ VPC CNI + kube-proxy\n+ node group")
        with Cluster("Helm add-ons (bootstrap job)"):
            s_addons = Nginx("nginx -> external-dns ->\ncert-manager(+issuer) ->\nargocd -> kube-prometheus ->\nloki -> ebs-csi")

        s_tf >> s_eks >> s_addons

    # ---------------- Cilium lane ----------------
    with Cluster("create-cilium-cluster.yml   (workspace: cilium-cluster)"):
        c_tf1 = Terraform("apply #1\ncilium-wo-nodegroup.tfvars\n(cluster only, no nodes)")
        c_eks = EKS("EKS + VPC + IRSA\n(no CNI, no kube-proxy)")
        c_crd = CRD("Gateway API CRDs v1.5.1\n+ TLSRoute v1.4.1")
        c_cil = Custom("helm install\nCilium 1.19.3\neBPF + Hubble + GwAPI", ICON("cilium"))
        c_tf2 = Terraform("apply #2\ncilium-with-nodegroup.tfvars\n(add nodes + CoreDNS)")
        with Cluster("Helm add-ons (bootstrap job)"):
            c_addons = Nginx("external-dns -> cert-manager ->\nargocd -> kube-prometheus ->\nloki -> tetragon -> ebs-csi")

        c_tf1 >> c_eks >> c_crd >> c_cil >> c_tf2 >> c_addons

    gha >> role
    role >> Edge(label="standard") >> s_tf
    role >> Edge(label="cilium") >> c_tf1

    # highlight the ordering constraint unique to Cilium
    c_eks >> Edge(label="CNI must be installed\nBEFORE nodes go Ready",
                  color="firebrick", style="bold", fontcolor="firebrick") >> c_cil
