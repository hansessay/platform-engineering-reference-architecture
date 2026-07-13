resource "helm_release" "rook_ceph_operator" {
  name             = "rook-ceph"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph"
  namespace        = "rook-ceph"
  create_namespace = true

  values = [
    file("${path.module}/../../../platform/rook-ceph/operator/values.yaml")
  ]

  timeout = 900
  wait    = true
}