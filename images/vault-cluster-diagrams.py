from diagrams import Cluster, Diagram
from diagrams.aws.compute import Compute
from diagrams.gcp.compute import GCE, GKE
from diagrams.gcp.network import DNS, LoadBalancing
from diagrams.gcp.security import KMS
from diagrams.gcp.storage import GCS
from diagrams.k8s.infra import Master
from diagrams.onprem.ci import Jenkins
from diagrams.onprem.compute import Server
from diagrams.onprem.network import Consul
from diagrams.onprem.security import Vault

# Generate a Vault Diagram using https://github.com/mingrammer/diagrams/tree/master/diagrams
# sudo apt-get install graphviz
# sudo pip3 install diagrams

graph_attr = {
    'fontsize' : '45',
    'bgcolor': 'transparent'
}
with Diagram('Interacting with Vault', show=False):
    with Cluster('Consumers'):
        with Cluster('Cloud'):
            gcp_cloud = GCE('GCP Cloud')
            aws_cloud = Compute('AWS Cloud')
            k8s_cloud = Master('K8S')
        with Cluster('On-Premise'):
            on_premise = Server("On-Premise\nServer")
            orch = Jenkins('Orchestrator')
            k8s_premise = Master('K8S')

    cluster_dns = DNS('vault-cluster.corp.com')
    
    with Cluster('Vault Cluster'):
        cluster_lb = LoadBalancing("GCP ILB")
        cluster_kms = KMS("GCP KMS")
        cluster_bucket = GCS("Consul Backup\nBucket")
        with Cluster('Vault Frontend'):
            frontend_1 = Vault('Primary Server')
            frontend_2 = Vault('Standby Server')
        with Cluster('Vault Backend'):
            backend_1 = Consul('Consul Leader')
            backend_2 = Consul('Consul Server')
            backend_3 = Consul('Consul Server')
    
    # Arranges the dependencies
    k8s_cloud >> cluster_dns
    k8s_premise >> cluster_dns
    cluster_dns >> cluster_lb
    cluster_lb >> frontend_1 >> backend_1
    frontend_1 >> cluster_kms
    backend_1 >> cluster_bucket
    
    # Clusters certain resources
    backend_1 - backend_2 - backend_3
    cluster_kms - cluster_bucket
    frontend_1 - frontend_2
    gcp_cloud - aws_cloud - k8s_cloud
    on_premise - orch - k8s_premise
