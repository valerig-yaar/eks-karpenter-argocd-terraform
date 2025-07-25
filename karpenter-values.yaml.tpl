nodeSelector:
  karpenter.sh/controller: 'true'
dnsPolicy: Default
settings:
  clusterName: ${cluster_name}
  clusterEndpoint: ${cluster_endpoint}
  interruptionQueue: ${interruption_queue}
webhook:
  enabled: false
