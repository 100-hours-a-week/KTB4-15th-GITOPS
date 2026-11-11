#!/usr/bin/env ruby

require "yaml"
require "json"

def load_yaml(file)
  YAML.safe_load(File.read(file), aliases: true)
end

domains = {
  "web" => ["web-bff"],
  "identity" => ["body-image-validator", "identity-api"],
  "commerce" => ["commerce-api", "price-crawler"],
  "chat" => ["chat-ai", "chat-api"],
  "fitting" => ["fitting-api", "fitting-worker", "vton-orchestrator"]
}.freeze

environments = %w[dev prod].freeze
application_names = []
gitops_repository = "https://github.com/100-hours-a-week/KTB4-15th-GITOPS.git"
in_cluster_server = "https://kubernetes.default.svc"
dev_namespaces = %w[
  lookddak-web
  lookddak-identity
  lookddak-commerce
  lookddak-chat
  lookddak-fitting
].freeze
notification_subscription = "notifications.argoproj.io/subscribe.on-deploy-failed.awssqs"
notification_queue = "lookddak-alert-queue"

argocd_files = %w[
  platform/dev/argocd/Chart.yaml
  platform/dev/argocd/Chart.lock
  platform/dev/argocd/values.yaml
  platform/dev/argocd/README.md
  platform/dev/argocd/system-node-isolation.md
  argocd/projects/lookddak-dev-argocd.yaml
  argocd/dev/argocd-application.yaml
].freeze

prod_argocd_files = %w[
  platform/prod/argocd/Chart.yaml
  platform/prod/argocd/Chart.lock
  platform/prod/argocd/values.yaml
  platform/prod/argocd/README.md
  platform/prod/argocd/templates/httproute.yaml
  argocd/projects/lookddak-prod.yaml
  argocd/projects/lookddak-prod-argocd.yaml
  argocd/prod/root-application.yaml
  argocd/prod/bootstrap/argocd-application.yaml
  argocd/prod/bootstrap/namespaces.yaml
  argocd/prod/bootstrap/workloads-application.yaml
].freeze

prod_platform_charts = %w[
  karpenter/crd
  karpenter/controller
  metrics-server
  secrets-store-csi/driver
  secrets-store-csi/provider-aws
  networking/aws-load-balancer-controller
  networking/istio/base
  networking/istio/istiod
  networking/istio/cni
  networking/istio/ztunnel
  cert-manager/controller
].freeze

prod_platform_files = (
  prod_platform_charts.flat_map { |chart| %W[platform/prod/#{chart}/Chart.yaml platform/prod/#{chart}/Chart.lock platform/prod/#{chart}/values.yaml] } +
  %w[
    argocd/projects/lookddak-prod-platform.yaml
    argocd/prod/platform/karpenter-crd-application.yaml
    argocd/prod/platform/karpenter-controller-application.yaml
    argocd/prod/platform/karpenter-nodepool-application.yaml
    argocd/prod/platform/metrics-server-application.yaml
    argocd/prod/platform/secrets-store-csi-driver-application.yaml
    argocd/prod/platform/secrets-store-csi-provider-aws-application.yaml
    argocd/prod/platform/aws-load-balancer-controller-application.yaml
    argocd/prod/platform/cert-manager-application.yaml
    argocd/prod/platform/cert-manager-issuers-application.yaml
    argocd/prod/platform/gateway-api-crds-application.yaml
    argocd/prod/platform/istio-base-application.yaml
    argocd/prod/platform/istiod-application.yaml
    argocd/prod/platform/istio-cni-application.yaml
    argocd/prod/platform/ztunnel-application.yaml
    argocd/prod/platform/istio-gateway-application.yaml
    platform/prod/karpenter/README.md
    platform/prod/karpenter/nodepool/ec2-nodeclass.yaml
    platform/prod/karpenter/nodepool/nodepool.yaml
    platform/prod/metrics-server/README.md
    platform/prod/secrets-store-csi/README.md
    platform/prod/networking/aws-load-balancer-controller/README.md
    platform/prod/cert-manager/README.md
    platform/prod/cert-manager/issuers/cluster-issuers.yaml
    platform/prod/networking/istio/README.md
    platform/prod/networking/gateway/README.md
    platform/prod/networking/gateway/gateway.yaml
    platform/prod/networking/gateway/gateway-options.yaml
    platform/prod/networking/gateway/certificate.yaml
    platform/prod/networking/gateway/telemetry.yaml
  ]
).freeze

karpenter_files = %w[
  platform/dev/karpenter/README.md
  platform/dev/karpenter/crd/Chart.yaml
  platform/dev/karpenter/crd/Chart.lock
  platform/dev/karpenter/crd/values.yaml
  platform/dev/karpenter/controller/Chart.yaml
  platform/dev/karpenter/controller/Chart.lock
  platform/dev/karpenter/controller/values.yaml
  argocd/projects/lookddak-dev-platform.yaml
  argocd/dev/karpenter-crd-application.yaml
  argocd/dev/karpenter-controller-application.yaml
  argocd/dev/karpenter-nodepool-application.yaml
  platform/dev/karpenter/nodepool/ec2-nodeclass.yaml
  platform/dev/karpenter/nodepool/nodepool.yaml
  platform/dev/karpenter/nodepool/README.md
].freeze

metrics_server_files = %w[
  platform/dev/metrics-server/Chart.yaml
  platform/dev/metrics-server/Chart.lock
  platform/dev/metrics-server/values.yaml
  platform/dev/metrics-server/README.md
  argocd/dev/metrics-server-application.yaml
].freeze

secrets_store_csi_files = %w[
  platform/dev/secrets-store-csi/README.md
  platform/dev/secrets-store-csi/driver/Chart.yaml
  platform/dev/secrets-store-csi/driver/Chart.lock
  platform/dev/secrets-store-csi/driver/values.yaml
  platform/dev/secrets-store-csi/provider-aws/Chart.yaml
  platform/dev/secrets-store-csi/provider-aws/Chart.lock
  platform/dev/secrets-store-csi/provider-aws/values.yaml
  argocd/dev/secrets-store-csi-driver-application.yaml
  argocd/dev/secrets-store-csi-provider-aws-application.yaml
].freeze

prod_cilium_files = %w[
  platform/prod/networking/cilium/README.md
  platform/prod/networking/cilium/values.yaml
].freeze

aws_load_balancer_controller_files = %w[
  platform/dev/networking/aws-load-balancer-controller/Chart.yaml
  platform/dev/networking/aws-load-balancer-controller/Chart.lock
  platform/dev/networking/aws-load-balancer-controller/values.yaml
  platform/dev/networking/aws-load-balancer-controller/README.md
  argocd/dev/aws-load-balancer-controller-application.yaml
].freeze

istio_charts = %w[base istiod cni ztunnel].freeze
istio_files = istio_charts.flat_map do |chart|
  %W[platform/dev/networking/istio/#{chart}/Chart.yaml platform/dev/networking/istio/#{chart}/Chart.lock platform/dev/networking/istio/#{chart}/values.yaml]
end + %w[
  platform/dev/networking/istio/README.md
  platform/dev/networking/gateway-api/crds/standard-install.yaml
  platform/dev/networking/gateway-api/README.md
  argocd/dev/namespace-istio-system.yaml
  argocd/dev/gateway-api-crds-application.yaml
  argocd/dev/istio-base-application.yaml
  argocd/dev/istiod-application.yaml
  argocd/dev/istio-cni-application.yaml
  argocd/dev/ztunnel-application.yaml
]

cert_manager_files = %w[
  platform/dev/cert-manager/README.md
  platform/dev/cert-manager/controller/Chart.yaml
  platform/dev/cert-manager/controller/Chart.lock
  platform/dev/cert-manager/controller/values.yaml
  platform/dev/cert-manager/issuers/cluster-issuers.yaml
  argocd/dev/cert-manager-application.yaml
  argocd/dev/cert-manager-issuers-application.yaml
].freeze

istio_gateway_files = %w[
  platform/dev/networking/gateway/README.md
  platform/dev/networking/gateway/gateway.yaml
  platform/dev/networking/gateway/gateway-options.yaml
  platform/dev/networking/gateway/certificate.yaml
  argocd/dev/namespace-istio-ingress.yaml
  argocd/dev/istio-gateway-application.yaml
].freeze

network_policy_files = %w[
  platform/dev/networking/policies/README.md
  platform/dev/networking/policies/domain-baseline.yaml
  platform/dev/networking/policies/domain-same-namespace.yaml
  platform/dev/networking/policies/hubble-relay.yaml
  argocd/dev/network-policies-application.yaml
].freeze

mesh_security_files = %w[
  platform/dev/networking/mesh-security/README.md
  platform/dev/networking/mesh-security/peer-authentication.yaml
  argocd/dev/mesh-security-application.yaml
  charts/lookddak-domain/templates/authorization-policy.yaml
].freeze

internal_api_files = %w[
  platform/dev/networking/internal-api/README.md
  platform/dev/networking/internal-api/waypoint.yaml
  platform/dev/networking/internal-api/api-service.yaml
  platform/dev/networking/internal-api/api-httproute.yaml
  platform/dev/networking/internal-api/reference-grants.yaml
  platform/dev/networking/internal-api/authorization-policy.yaml
  platform/dev/networking/policies/web-waypoint.yaml
  argocd/dev/internal-api-application.yaml
].freeze

ai_waypoint_files = %w[
  platform/dev/networking/ai-waypoint/README.md
  platform/dev/networking/ai-waypoint/identity-waypoint.yaml
  platform/dev/networking/ai-waypoint/chat-egress-waypoint.yaml
  platform/dev/networking/ai-waypoint/chat-egress-services.yaml
  platform/dev/networking/policies/ai-waypoint.yaml
  argocd/dev/ai-waypoint-application.yaml
].freeze

monitoring_charts = %w[prometheus loki tempo alloy-node kube-state-metrics alloy-cluster grafana].freeze
monitoring_files = (
  monitoring_charts.flat_map { |chart| %W[platform/dev/observability/#{chart}/Chart.yaml platform/dev/observability/#{chart}/Chart.lock platform/dev/observability/#{chart}/values.yaml argocd/dev/#{chart}-application.yaml] } +
  %w[
    platform/dev/observability/README.md
    platform/dev/storage/README.md
    platform/dev/storage/storageclass-gp3.yaml
    argocd/dev/storage-application.yaml
    argocd/dev/namespace-monitoring.yaml
    platform/dev/scheduling/README.md
    platform/dev/scheduling/priority-classes.yaml
    argocd/dev/scheduling-application.yaml
    platform/dev/networking/policies/alloy-cluster-scrape.yaml
    platform/dev/networking/policies/domain-otlp-export.yaml
    platform/dev/networking/gateway/telemetry.yaml
    platform/dev/networking/gateway/grafana-ext-authz.yaml
    platform/dev/networking/policies/monitoring-grafana.yaml
    platform/dev/observability/grafana-auth/deployment.yaml
    platform/dev/observability/grafana-auth/service.yaml
    platform/dev/observability/grafana-auth/serviceaccount.yaml
    platform/dev/observability/grafana-auth/secret-provider-class.yaml
    platform/dev/observability/grafana-auth/httproute.yaml
    argocd/dev/grafana-auth-application.yaml
    platform/dev/observability/db-log-tailer/deployment.yaml
    platform/dev/observability/db-log-tailer/serviceaccount.yaml
    platform/dev/observability/db-log-tailer/pvc.yaml
    argocd/dev/db-log-tailer-application.yaml
  ]
).freeze

dev_image_automation_files = %w[
  .github/workflows/update-dev-image.yaml
  scripts/update-dev-image.rb
  scripts/test-update-dev-image.rb
].freeze

prod_image_automation_files = %w[
  .github/workflows/promote-prod-image.yaml
  scripts/update-prod-image.rb
  scripts/validate-prod-image-change.rb
  scripts/test-update-prod-image.rb
  scripts/test-validate-prod-image-change.rb
  scripts/render-prod-image-workloads.sh
  scripts/diff-prod-image-manifests.sh
].freeze

[argocd_files, prod_argocd_files, prod_platform_files, karpenter_files, metrics_server_files, secrets_store_csi_files, prod_cilium_files, aws_load_balancer_controller_files, istio_files, cert_manager_files, istio_gateway_files, network_policy_files, mesh_security_files, internal_api_files, ai_waypoint_files, monitoring_files, dev_image_automation_files, prod_image_automation_files].flatten.each do |file|
  abort "필수 파일 누락: #{file}" unless File.file?(file)
end

prod_cilium_values_file = "platform/prod/networking/cilium/values.yaml"
prod_cilium = load_yaml(prod_cilium_values_file)
unless prod_cilium["kubeProxyReplacement"] == true &&
       prod_cilium["k8sServiceHost"] == "98FAA5345EEC969890293E6E0090CC4C.gr7.ap-northeast-2.eks.amazonaws.com" &&
       prod_cilium["k8sServicePort"] == 443
  abort "#{prod_cilium_values_file}: Prod EKS Private API를 사용하는 kube-proxy replacement 설정이 필요합니다."
end
unless prod_cilium.dig("ipam", "mode") == "eni" &&
       prod_cilium["routingMode"] == "native" &&
       prod_cilium.dig("eni", "enabled") == true &&
       prod_cilium.dig("eni", "iamRole") == "arn:aws:iam::686496667254:role/lookddak-prod-cilium-operator" &&
       prod_cilium.dig("eni", "awsEnablePrefixDelegation") == true &&
       prod_cilium.dig("eni", "awsReleaseExcessIPs") == true &&
       prod_cilium.dig("eni", "subnetTagsFilter") == ["Tier=private-pod"] &&
       prod_cilium.dig("eni", "nodeSpec", "firstInterfaceIndex") == 1
  abort "#{prod_cilium_values_file}: Prod ENI IPAM·IRSA·Pod Subnet·Prefix Delegation 설정이 예상과 다릅니다."
end
unless prod_cilium.dig("cni", "exclusive") == false &&
       prod_cilium.dig("socketLB", "hostNamespaceOnly") == true &&
       prod_cilium.dig("bpf", "hostLegacyRouting") == true &&
       prod_cilium.dig("envoy", "enabled") == false &&
       prod_cilium.dig("prometheus", "enabled") == true &&
       prod_cilium.dig("hubble", "enabled") == true &&
       (prod_cilium.dig("hubble", "metrics", "enabled") || []).include?("flow:sourceContext=namespace;destinationContext=namespace") &&
       prod_cilium.dig("hubble", "relay", "enabled") == false &&
       prod_cilium.dig("hubble", "ui", "enabled") == false
  abort "#{prod_cilium_values_file}: Istio Ambient 공존과 kubelet probe 대응 설정이 필요합니다."
end
prod_cilium_operator = prod_cilium.fetch("operator")
unless prod_cilium_operator["replicas"] == 2 &&
       prod_cilium_operator.dig("prometheus", "enabled") == true &&
       prod_cilium_operator.dig("nodeSelector", "lookddak.io/node-pool") == "system" &&
       (prod_cilium_operator["tolerations"] || []).any? { |item| item["key"] == "node.kubernetes.io/not-ready" } &&
       (prod_cilium_operator["tolerations"] || []).any? { |item| item["key"] == "CriticalAddonsOnly" }
  abort "#{prod_cilium_values_file}: Cilium Operator 2개를 NotReady·System Node에 Bootstrap할 수 있어야 합니다."
end

environments.each do |environment|
  images_file = "environments/#{environment}/images.yaml"
  abort "필수 파일 누락: #{images_file}" unless File.file?(images_file)

  actual_domains = Dir["environments/#{environment}/domains/*"]
    .select { |path| File.directory?(path) }
    .map { |path| File.basename(path) }
    .sort

  unless actual_domains == domains.keys.sort
    abort "#{environment}: 도메인 구성이 설계와 다릅니다. 예상=#{domains.keys.sort}, 실제=#{actual_domains}"
  end

  domains.each do |domain, expected_workloads|
    domain_file = "environments/#{environment}/domains/#{domain}/domain.yaml"
    abort "필수 파일 누락: #{domain_file}" unless File.file?(domain_file)

    application_names << "#{environment}-#{domain}-domain"

    pattern = "environments/#{environment}/domains/#{domain}/workloads/*.yaml"
    workload_files = Dir[pattern].sort
    actual_workloads = workload_files.map { |file| File.basename(file, ".yaml") }

    unless actual_workloads == expected_workloads.sort
      abort "#{environment}/#{domain}: 워크로드 구성이 설계와 다릅니다. 예상=#{expected_workloads.sort}, 실제=#{actual_workloads}"
    end

    workload_files.each do |file|
      values = load_yaml(file)
      workload = values.fetch("workload")
      name = workload.fetch("name")
      type = workload.fetch("type")
      basename = File.basename(file, ".yaml")

      abort "#{file}: workload.name과 파일명이 다릅니다." unless name == basename
      abort "#{file}: 지원하지 않는 workload.type '#{type}'입니다." unless %w[deployment cronjob].include?(type)
      abort "#{file}: 지원하지 않는 imageGroup입니다." unless %w[fe be ai crawler].include?(values.fetch("imageGroup"))

      if environment == "dev"
        auto_sync = values.fetch("gitops").fetch("autoSync")
        unless [true, false].include?(auto_sync)
          abort "#{file}: gitops.autoSync는 true 또는 false여야 합니다."
        end
      end

      application_names << "#{environment}-#{name}"
    end
  end
end

duplicates = application_names.group_by(&:itself).select { |_, names| names.length > 1 }.keys
abort "중복 Application 이름: #{duplicates.join(', ')}" unless duplicates.empty?

expected_sets = {
  "argocd/dev/domain-applicationset.yaml" => "environments/dev/domains/*/domain.yaml",
  "argocd/dev/workload-applicationset.yaml" => "environments/dev/domains/*/workloads/*.yaml",
  "argocd/prod/domain-applicationset.yaml" => "environments/prod/domains/*/domain.yaml",
  "argocd/prod/workload-applicationset.yaml" => "environments/prod/domains/*/workloads/*.yaml"
}.freeze

expected_sets.each do |file, expected_path|
  abort "필수 파일 누락: #{file}" unless File.file?(file)
  manifest = load_yaml(file)
  actual_path = manifest.dig("spec", "generators", 0, "git", "files", 0, "path")
  abort "#{file}: Git generator 경로가 예상과 다릅니다." unless actual_path == expected_path
end

chart_repositories_by_project = Hash.new { |hash, key| hash[key] = [] }
Dir["argocd/dev/*-application.yaml"].sort.each do |file|
  application = load_yaml(file)
  chart_file = File.join(application.dig("spec", "source", "path").to_s, "Chart.yaml")
  next unless File.file?(chart_file)
  repositories = (load_yaml(chart_file)["dependencies"] || []).map { |dependency| dependency["repository"] }
  chart_repositories_by_project[application.dig("spec", "project")].concat(repositories)
end
expected_source_repos = ->(project) { [gitops_repository] + chart_repositories_by_project[project].uniq.sort }

dev_project_file = "argocd/projects/lookddak-dev.yaml"
dev_project = load_yaml(dev_project_file)
abort "#{dev_project_file}: kind가 AppProject가 아닙니다." unless dev_project["kind"] == "AppProject"
abort "#{dev_project_file}: 허용 Repository가 예상과 다릅니다." unless dev_project.dig("spec", "sourceRepos") == [gitops_repository]

dev_destination = dev_project.dig("spec", "destinations", 0)
unless dev_destination == { "server" => in_cluster_server, "namespace" => "lookddak-*" }
  abort "#{dev_project_file}: dev 배포 대상 Cluster 또는 Namespace 범위가 예상과 다릅니다."
end

unless dev_project.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-2"
  abort "#{dev_project_file}: Root 동기화 전에 적용할 sync-wave -2가 필요합니다."
end
unless dev_project.dig("metadata", "annotations", notification_subscription) == notification_queue
  abort "#{dev_project_file}: 모든 Dev 워크로드의 배포 실패 SQS 구독이 필요합니다."
end

root_file = "argocd/dev/root-application.yaml"
abort "필수 파일 누락: #{root_file}" unless File.file?(root_file)
root = load_yaml(root_file)
abort "#{root_file}: kind가 Application이 아닙니다." unless root["kind"] == "Application"
abort "#{root_file}: Application 이름이 예상과 다릅니다." unless root.dig("metadata", "name") == "lookddak-dev-root"
abort "#{root_file}: Application은 argocd Namespace에 있어야 합니다." unless root.dig("metadata", "namespace") == "argocd"
abort "#{root_file}: Root Application은 default Project에서 부트스트랩해야 합니다." unless root.dig("spec", "project") == "default"

root_sources = root.dig("spec", "sources") || []
expected_root_sources = {
  "argocd/projects" => "lookddak-dev*.yaml",
  "argocd/dev" => nil
}

actual_root_sources = root_sources.to_h do |source|
  abort "#{root_file}: Root source는 Public GitOps Repository만 사용할 수 있습니다." unless source["repoURL"] == gitops_repository
  abort "#{root_file}: Root source는 main 브랜치를 추적해야 합니다." unless source["targetRevision"] == "main"
  [source["path"], source.dig("directory", "include")]
end

abort "#{root_file}: Root 관리 경로가 예상과 다릅니다." unless actual_root_sources == expected_root_sources

unless root.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "argocd" }
  abort "#{root_file}: Root 배포 대상은 현재 Cluster의 argocd Namespace여야 합니다."
end

root_automation = root.dig("spec", "syncPolicy", "automated") || {}
expected_root_automation = {
  "enabled" => true,
  "prune" => true,
  "selfHeal" => true,
  "allowEmpty" => false
}
abort "#{root_file}: Root Auto Sync 안전 정책이 예상과 다릅니다." unless root_automation == expected_root_automation

argocd_project_file = "argocd/projects/lookddak-dev-argocd.yaml"
argocd_project = load_yaml(argocd_project_file)
unless argocd_project["kind"] == "AppProject" && argocd_project.dig("metadata", "name") == "lookddak-dev-argocd" && argocd_project.dig("metadata", "namespace") == "argocd"
  abort "#{argocd_project_file}: Argo CD 전용 AppProject 신원이 예상과 다릅니다."
end
unless argocd_project.dig("spec", "sourceRepos") == expected_source_repos.call("lookddak-dev-argocd") && argocd_project.dig("spec", "destinations") == [{ "server" => in_cluster_server, "namespace" => "argocd" }]
  abort "#{argocd_project_file}: Argo CD 전용 Project는 GitOps 저장소·Argo CD Chart 저장소와 현재 Cluster의 argocd Namespace만 허용해야 합니다."
end
unless argocd_project.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-2"
  abort "Argo CD 전용 Project는 Application보다 먼저 선언해야 합니다."
end
unless argocd_project.dig("metadata", "annotations", notification_subscription) == notification_queue
  abort "Argo CD 전용 Project의 배포 실패 SQS 구독이 필요합니다."
end
expected_argocd_cluster_resources = [
  { "group" => "apiextensions.k8s.io", "kind" => "CustomResourceDefinition" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRole" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRoleBinding" }
]
unless argocd_project.dig("spec", "clusterResourceWhitelist") == expected_argocd_cluster_resources
  abort "Argo CD 전용 Project에는 설치 Chart에 필요한 Cluster 범위 종류만 허용해야 합니다."
end

argocd_app_file = "argocd/dev/argocd-application.yaml"
argocd_app = load_yaml(argocd_app_file)
unless argocd_app["kind"] == "Application" && argocd_app.dig("metadata", "name") == "argocd" && argocd_app.dig("metadata", "namespace") == "argocd"
  abort "#{argocd_app_file}: 기존 Helm Release와 동일한 argocd Application 이름을 사용해야 합니다."
end
unless argocd_app.dig("spec", "project") == "lookddak-dev-argocd" && argocd_app.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "argocd" }
  abort "Argo CD 자기 관리 Application의 Project·배포 대상이 예상과 다릅니다."
end
unless argocd_app.dig("spec", "source") == { "repoURL" => gitops_repository, "targetRevision" => "main", "path" => "platform/dev/argocd", "helm" => { "releaseName" => "argocd" } }
  abort "Argo CD 자기 관리는 main의 기존 Wrapper Chart와 releaseName=argocd를 사용해야 합니다."
end
unless argocd_app.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "1" && argocd_app.dig("spec", "syncPolicy", "automated") == expected_root_automation
  abort "Argo CD 자기 관리 Application의 Sync Wave·자동 동기화 정책이 예상과 다릅니다."
end
unless argocd_app.dig("spec", "ignoreDifferences") == [{ "group" => "", "kind" => "Secret", "name" => "argocd-secret", "namespace" => "argocd", "jsonPointers" => ["/data"] }] && argocd_app.dig("spec", "syncPolicy", "syncOptions") == ["RespectIgnoreDifferences=true", "PruneLast=true"]
  abort "Argo CD 런타임 Secret 데이터의 비교·적용 제외 설정이 필요합니다."
end
abort "Argo CD 자기 관리 Application에는 연쇄 삭제 Finalizer를 추가하지 않습니다." unless (argocd_app.dig("metadata", "finalizers") || []).empty?

argocd_chart = load_yaml("platform/dev/argocd/Chart.yaml")
argocd_dependency = argocd_chart.fetch("dependencies").find { |item| item["name"] == "argo-cd" }
unless argocd_dependency && argocd_dependency["version"] == "10.11.6" && argocd_dependency["repository"] == "https://argoproj.github.io/argo-helm"
  abort "Argo CD 전환에서는 기존 공식 Chart 10.11.6을 유지해야 합니다."
end

prod_root_file = "argocd/prod/root-application.yaml"
prod_root = load_yaml(prod_root_file)
unless prod_root["kind"] == "Application" &&
       prod_root.dig("metadata", "name") == "lookddak-prod-root" &&
       prod_root.dig("metadata", "namespace") == "argocd" &&
       prod_root.dig("spec", "project") == "default"
  abort "#{prod_root_file}: Prod Root Application 신원이 예상과 다릅니다."
end
prod_root_sources = (prod_root.dig("spec", "sources") || []).to_h do |source|
  abort "#{prod_root_file}: Public GitOps main만 Source로 사용해야 합니다." unless source["repoURL"] == gitops_repository && source["targetRevision"] == "main"
  [source["path"], source.dig("directory", "include")]
end
expected_prod_root_sources = {
  "argocd/projects" => "lookddak-prod*.yaml",
  "argocd/prod/bootstrap" => nil,
  "argocd/prod/platform" => nil
}
abort "#{prod_root_file}: Root는 Bootstrap과 Platform 경로만 직접 관리해야 합니다." unless prod_root_sources == expected_prod_root_sources
unless prod_root.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "argocd" } &&
       prod_root.dig("spec", "syncPolicy", "automated") == expected_root_automation &&
       prod_root.dig("spec", "syncPolicy", "syncOptions") == ["PruneLast=true"]
  abort "#{prod_root_file}: Prod Root의 배포 대상·Auto Sync 안전 정책이 예상과 다릅니다."
end

prod_active_application_files = Dir["argocd/prod/workloads/*.yaml"].sort
expected_prod_active_application_files = %w[
  argocd/prod/workloads/body-image-validator-application.yaml
  argocd/prod/workloads/chat-ai-application.yaml
  argocd/prod/workloads/chat-api-application.yaml
  argocd/prod/workloads/chat-domain-application.yaml
  argocd/prod/workloads/commerce-api-application.yaml
  argocd/prod/workloads/commerce-domain-application.yaml
  argocd/prod/workloads/fitting-api-application.yaml
  argocd/prod/workloads/fitting-domain-application.yaml
  argocd/prod/workloads/fitting-worker-application.yaml
  argocd/prod/workloads/identity-api-application.yaml
  argocd/prod/workloads/identity-domain-application.yaml
  argocd/prod/workloads/price-crawler-application.yaml
  argocd/prod/workloads/vton-orchestrator-application.yaml
  argocd/prod/workloads/web-bff-application.yaml
  argocd/prod/workloads/web-domain-application.yaml
]
unless prod_active_application_files == expected_prod_active_application_files
  abort "Prod 단계 배포는 Web·Identity·Commerce·Chat·Fitting 전체 Domain과 승인된 Workload만 활성화해야 합니다. 실제=#{prod_active_application_files}"
end

prod_web_domain_app = load_yaml("argocd/prod/workloads/web-domain-application.yaml")
prod_web_workload_app = load_yaml("argocd/prod/workloads/web-bff-application.yaml")
expected_prod_automation = { "enabled" => true, "prune" => true, "selfHeal" => true, "allowEmpty" => false }

prod_workloads_loader = load_yaml("argocd/prod/bootstrap/workloads-application.yaml")
unless prod_workloads_loader.dig("metadata", "name") == "lookddak-prod-workloads" &&
       prod_workloads_loader.dig("metadata", "namespace") == "argocd" &&
       prod_workloads_loader.dig("spec", "project") == "lookddak-prod-argocd" &&
       prod_workloads_loader.dig("spec", "source") == {
         "repoURL" => gitops_repository,
         "targetRevision" => "main",
         "path" => "argocd/prod/workloads"
       } &&
       prod_workloads_loader.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "argocd" } &&
       prod_workloads_loader.dig("spec", "syncPolicy", "automated") == expected_prod_automation
  abort "Prod Workload Loader는 승인된 Application 디렉터리만 자동 동기화해야 합니다."
end

unless prod_web_domain_app.dig("metadata", "name") == "prod-web-domain" &&
       prod_web_domain_app.dig("metadata", "namespace") == "argocd" &&
       prod_web_domain_app.dig("spec", "project") == "lookddak-prod" &&
       prod_web_domain_app.dig("spec", "sources", 0, "path") == "charts/lookddak-domain" &&
       prod_web_domain_app.dig("spec", "sources", 0, "helm", "valueFiles") == ["$values/environments/prod/domains/web/domain.yaml"] &&
       prod_web_domain_app.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-web" } &&
       prod_web_domain_app.dig("spec", "syncPolicy", "automated") == expected_prod_automation
  abort "Prod Web Domain Application의 Chart·values·대상·Auto Sync 설정이 예상과 다릅니다."
end

unless prod_web_workload_app.dig("metadata", "name") == "prod-web-bff" &&
       prod_web_workload_app.dig("metadata", "namespace") == "argocd" &&
       prod_web_workload_app.dig("spec", "project") == "lookddak-prod" &&
       prod_web_workload_app.dig("spec", "sources", 0, "path") == "charts/lookddak-workload" &&
       prod_web_workload_app.dig("spec", "sources", 0, "helm", "valueFiles") == ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/web/workloads/web-bff.yaml"] &&
       prod_web_workload_app.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-web" } &&
       prod_web_workload_app.dig("spec", "syncPolicy", "automated") == expected_prod_automation
  abort "Prod web-bff Application의 Chart·values·대상·Auto Sync 설정이 예상과 다릅니다."
end

prod_identity_applications = {
  "identity-domain" => {
    file: "argocd/prod/workloads/identity-domain-application.yaml",
    chart: "charts/lookddak-domain",
    values: ["$values/environments/prod/domains/identity/domain.yaml"],
    wave: "2"
  },
  "body-image-validator" => {
    file: "argocd/prod/workloads/body-image-validator-application.yaml",
    chart: "charts/lookddak-workload",
    values: ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/identity/workloads/body-image-validator.yaml"],
    wave: "3"
  },
  "identity-api" => {
    file: "argocd/prod/workloads/identity-api-application.yaml",
    chart: "charts/lookddak-workload",
    values: ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/identity/workloads/identity-api.yaml"],
    wave: "4"
  }
}

prod_identity_applications.each do |name, expected|
  application = load_yaml(expected.fetch(:file))
  unless application.dig("metadata", "name") == "prod-#{name}" &&
         application.dig("metadata", "namespace") == "argocd" &&
         application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == expected.fetch(:wave) &&
         application.dig("spec", "project") == "lookddak-prod" &&
         application.dig("spec", "sources", 0, "path") == expected.fetch(:chart) &&
         application.dig("spec", "sources", 0, "helm", "valueFiles") == expected.fetch(:values) &&
         application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-identity" } &&
         application.dig("spec", "syncPolicy", "automated") == expected_prod_automation
    abort "#{expected.fetch(:file)}: Prod Identity 단계 Application 설정이 예상과 다릅니다."
  end
end

prod_commerce_applications = {
  "commerce-domain" => {
    file: "argocd/prod/workloads/commerce-domain-application.yaml",
    chart: "charts/lookddak-domain",
    values: ["$values/environments/prod/domains/commerce/domain.yaml"],
    wave: "5"
  },
  "commerce-api" => {
    file: "argocd/prod/workloads/commerce-api-application.yaml",
    chart: "charts/lookddak-workload",
    values: ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/commerce/workloads/commerce-api.yaml"],
    wave: "6"
  },
  "price-crawler" => {
    file: "argocd/prod/workloads/price-crawler-application.yaml",
    chart: "charts/lookddak-workload",
    values: ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/commerce/workloads/price-crawler.yaml"],
    wave: "7"
  }
}

prod_commerce_applications.each do |name, expected|
  application = load_yaml(expected.fetch(:file))
  unless application.dig("metadata", "name") == "prod-#{name}" &&
         application.dig("metadata", "namespace") == "argocd" &&
         application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == expected.fetch(:wave) &&
         application.dig("spec", "project") == "lookddak-prod" &&
         application.dig("spec", "sources", 0, "path") == expected.fetch(:chart) &&
         application.dig("spec", "sources", 0, "helm", "valueFiles") == expected.fetch(:values) &&
         application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-commerce" } &&
         application.dig("spec", "syncPolicy", "automated") == expected_prod_automation
    abort "#{expected.fetch(:file)}: Prod Commerce 단계 Application 설정이 예상과 다릅니다."
  end
end

prod_chat_applications = {
  "chat-domain" => {
    file: "argocd/prod/workloads/chat-domain-application.yaml",
    chart: "charts/lookddak-domain",
    values: ["$values/environments/prod/domains/chat/domain.yaml"],
    wave: "8"
  },
  "chat-ai" => {
    file: "argocd/prod/workloads/chat-ai-application.yaml",
    chart: "charts/lookddak-workload",
    values: ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/chat/workloads/chat-ai.yaml"],
    wave: "9"
  },
  "chat-api" => {
    file: "argocd/prod/workloads/chat-api-application.yaml",
    chart: "charts/lookddak-workload",
    values: ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/chat/workloads/chat-api.yaml"],
    wave: "10"
  }
}

prod_chat_applications.each do |name, expected|
  application = load_yaml(expected.fetch(:file))
  unless application.dig("metadata", "name") == "prod-#{name}" &&
         application.dig("metadata", "namespace") == "argocd" &&
         application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == expected.fetch(:wave) &&
         application.dig("spec", "project") == "lookddak-prod" &&
         application.dig("spec", "sources", 0, "path") == expected.fetch(:chart) &&
         application.dig("spec", "sources", 0, "helm", "valueFiles") == expected.fetch(:values) &&
         application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-chat" } &&
         application.dig("spec", "syncPolicy", "automated") == expected_prod_automation
    abort "#{expected.fetch(:file)}: Prod Chat 단계 Application 설정이 예상과 다릅니다."
  end
end

prod_fitting_applications = {
  "fitting-domain" => ["charts/lookddak-domain", ["$values/environments/prod/domains/fitting/domain.yaml"], "11"],
  "vton-orchestrator" => ["charts/lookddak-workload", ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/fitting/workloads/vton-orchestrator.yaml"], "12"],
  "fitting-worker" => ["charts/lookddak-workload", ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/fitting/workloads/fitting-worker.yaml"], "13"],
  "fitting-api" => ["charts/lookddak-workload", ["$values/environments/prod/images.yaml", "$values/environments/prod/domains/fitting/workloads/fitting-api.yaml"], "14"]
}

prod_fitting_applications.each do |name, expected|
  file = "argocd/prod/workloads/#{name}-application.yaml"
  application = load_yaml(file)
  unless application.dig("metadata", "name") == "prod-#{name}" &&
         application.dig("metadata", "namespace") == "argocd" &&
         application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == expected[2] &&
         application.dig("spec", "project") == "lookddak-prod" &&
         application.dig("spec", "sources", 0, "path") == expected[0] &&
         application.dig("spec", "sources", 0, "helm", "valueFiles") == expected[1] &&
         application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-fitting" } &&
         application.dig("spec", "syncPolicy", "automated") == expected_prod_automation
    abort "#{file}: Prod Fitting 단계 Application 설정이 예상과 다릅니다."
  end
end

prod_images = load_yaml("environments/prod/images.yaml").fetch("images")
prod_fe_image = prod_images.fetch("fe")
unless prod_fe_image.fetch("repository").match?(%r{\A686496667254\.dkr\.ecr\.ap-northeast-2\.amazonaws\.com/lookddak-dev-nextjs\z}) &&
       prod_fe_image.fetch("digest").match?(/\Asha256:[0-9a-f]{64}\z/)
  abort "Prod FE 이미지는 Dev에서 검증한 ECR repository와 불변 digest를 사용해야 합니다."
end

expected_prod_identity_images = {
  "be" => "686496667254.dkr.ecr.ap-northeast-2.amazonaws.com/lookddak-dev-spring",
  "ai" => "686496667254.dkr.ecr.ap-northeast-2.amazonaws.com/lookddak-dev-fastapi"
}
expected_prod_identity_images.each do |group, repository|
  image = prod_images.fetch(group)
  unless image.fetch("repository") == repository && image.fetch("digest").match?(/\Asha256:[0-9a-f]{64}\z/)
    abort "Prod #{group.upcase} 이미지는 Dev에서 검증한 ECR repository와 불변 digest를 사용해야 합니다."
  end
end

prod_crawler_image = prod_images.fetch("crawler")
unless prod_crawler_image.fetch("repository") == "686496667254.dkr.ecr.ap-northeast-2.amazonaws.com/lookddak-dev-crawler" &&
       prod_crawler_image.fetch("digest").match?(/\Asha256:[0-9a-f]{64}\z/)
  abort "Prod CRAWLER 이미지는 Dev에서 검증한 ECR repository와 불변 digest를 사용해야 합니다."
end

prod_web_values = load_yaml("environments/prod/domains/web/workloads/web-bff.yaml")
prod_web_spread = prod_web_values.dig("scheduling", "topologySpreadConstraints") || []
unless prod_web_values["replicaCount"] == 2 &&
       prod_web_values.dig("container", "port") == 3000 &&
       prod_web_values.dig("service", "enabled") == true &&
       prod_web_values.dig("service", "port") == 80 &&
       prod_web_values.dig("pdb") == { "enabled" => true, "minAvailable" => 1 } &&
       %w[startup liveness readiness].all? { |probe| prod_web_values.dig("probes", probe, "httpGet", "path") == "/health" } &&
       %w[topology.kubernetes.io/zone kubernetes.io/hostname].all? do |key|
         prod_web_spread.any? { |rule| rule["topologyKey"] == key && rule["minDomains"] == 2 && rule["whenUnsatisfiable"] == "DoNotSchedule" }
       end
  abort "Prod web-bff는 2개 Pod·Probe·PDB·AZ/Node 강제 분산 설정이 필요합니다."
end

prod_identity_workloads = {
  "identity-api" => {
    image_group: "be",
    port: 8080,
    role: "arn:aws:iam::686496667254:role/lookddak-prod-v3-identity-api",
    probe_paths: ["/actuator/health/liveness", "/actuator/health/liveness", "/actuator/health/readiness"],
    parameters: %w[
      /lookddak/prod/v3/mysql/jdbc-url
      /lookddak/prod/v3/mysql/app/username
      /lookddak/prod/v3/mysql/app/password
      /lookddak/prod/spring/jwt-secret
      /lookddak/prod/internal/ai-api-key
      /lookddak/prod/v3/s3/images/bucket
    ]
  },
  "body-image-validator" => {
    image_group: "ai",
    port: 8000,
    role: "arn:aws:iam::686496667254:role/lookddak-prod-v3-body-image-validator",
    probe_paths: ["/health", "/health", "/health"],
    parameters: %w[
      /lookddak/prod/internal/ai-api-key
      /lookddak/prod/fastapi/body-image-validation/url
      /lookddak/prod/fastapi/body-image-validation/proxy-key
      /lookddak/prod/fastapi/body-image-validation/proxy-secret
      /lookddak/prod/fastapi/body-image-validation/api-key
      /lookddak/prod/fastapi/runware-vton-api-key
      /lookddak/prod/fastapi/runware-llm-api-key
    ]
  }
}

prod_identity_workloads.each do |name, expected|
  file = "environments/prod/domains/identity/workloads/#{name}.yaml"
  values = load_yaml(file)
  spread = values.dig("scheduling", "topologySpreadConstraints") || []
  probe_paths = %w[startup liveness readiness].map { |probe| values.dig("probes", probe, "httpGet", "path") }
  parameter_objects = YAML.safe_load(values.dig("secrets", "parameters", "objects")).map { |object| object.fetch("objectName") }

  unless values["imageGroup"] == expected.fetch(:image_group) &&
         values["replicaCount"] == 2 &&
         values.dig("container", "port") == expected.fetch(:port) &&
         values.dig("service") == { "enabled" => true, "port" => 80 } &&
         values.dig("pdb") == { "enabled" => true, "maxUnavailable" => 1 } &&
         values.dig("serviceAccount") == { "create" => true, "roleArn" => expected.fetch(:role) } &&
         values.dig("secrets", "enabled") == true &&
         values.dig("secrets", "rolloutOnChange") == true &&
         parameter_objects == expected.fetch(:parameters) &&
         probe_paths == expected.fetch(:probe_paths) &&
         %w[topology.kubernetes.io/zone kubernetes.io/hostname].all? do |key|
           spread.any? { |rule| rule["topologyKey"] == key && rule["minDomains"] == 2 && rule["whenUnsatisfiable"] == "DoNotSchedule" }
         end
    abort "#{file}: Prod Identity의 이미지·IRSA·Secret·Probe·PDB·AZ/Node 분산 설정이 예상과 다릅니다."
  end
end

prod_commerce_file = "environments/prod/domains/commerce/workloads/commerce-api.yaml"
prod_commerce = load_yaml(prod_commerce_file)
prod_commerce_spread = prod_commerce.dig("scheduling", "topologySpreadConstraints") || []
prod_commerce_parameters = YAML.safe_load(prod_commerce.dig("secrets", "parameters", "objects")).map { |object| object.fetch("objectName") }
unless prod_commerce["imageGroup"] == "be" &&
       prod_commerce["replicaCount"] == 2 &&
       prod_commerce.dig("container", "port") == 8080 &&
       prod_commerce.dig("service") == { "enabled" => true, "port" => 80 } &&
       prod_commerce.dig("pdb") == { "enabled" => true, "maxUnavailable" => 1 } &&
       prod_commerce.dig("serviceAccount") == { "create" => true, "roleArn" => "arn:aws:iam::686496667254:role/lookddak-prod-v3-commerce-api" } &&
       prod_commerce.dig("secrets", "enabled") == true &&
       prod_commerce.dig("secrets", "rolloutOnChange") == true &&
       prod_commerce_parameters == %w[/lookddak/prod/v3/mysql/jdbc-url /lookddak/prod/v3/mysql/app/username /lookddak/prod/v3/mysql/app/password /lookddak/prod/spring/jwt-secret /lookddak/prod/spring/internal-api-key] &&
       %w[startup liveness readiness].all? { |probe| prod_commerce.dig("probes", probe, "httpGet", "path").to_s.start_with?("/actuator/health/") } &&
       %w[topology.kubernetes.io/zone kubernetes.io/hostname].all? do |key|
         prod_commerce_spread.any? { |rule| rule["topologyKey"] == key && rule["minDomains"] == 2 && rule["whenUnsatisfiable"] == "DoNotSchedule" }
       end
  abort "#{prod_commerce_file}: Prod Commerce API의 이미지·IRSA·Secret·Probe·PDB·AZ/Node 분산 설정이 예상과 다릅니다."
end

prod_crawler_file = "environments/prod/domains/commerce/workloads/price-crawler.yaml"
prod_crawler = load_yaml(prod_crawler_file)
prod_cron = prod_crawler.fetch("cronJob")
prod_crawler_parameters = YAML.safe_load(prod_crawler.dig("secrets", "parameters", "objects")).map { |object| object.fetch("objectName") }
unless prod_crawler["imageGroup"] == "crawler" &&
       prod_crawler.dig("container", "env")&.include?({ "name" => "PRICE_REFRESH_BACKEND_BASE_URL", "value" => "http://commerce-api" }) &&
       prod_crawler.dig("serviceAccount") == { "create" => true, "roleArn" => "arn:aws:iam::686496667254:role/lookddak-prod-v3-price-crawler" } &&
       prod_crawler.dig("secrets", "enabled") == true &&
       prod_crawler.dig("secrets", "secretProviderClassName") == "price-crawler" &&
       prod_crawler_parameters == %w[/lookddak/prod/v3/postgresql/app/database-url /lookddak/prod/internal/price-refresh-backend-auth-headers] &&
       prod_cron["nameSuffix"] == "apply" &&
       prod_cron["schedule"] == "0 11 * * *" &&
       prod_cron["timeZone"] == "Asia/Seoul" &&
       prod_cron["suspend"] == false &&
       prod_cron["concurrencyPolicy"] == "Forbid" &&
       prod_cron["startingDeadlineSeconds"] == 3600 &&
       prod_cron["activeDeadlineSeconds"] == 3600 &&
       prod_crawler.dig("secrets", "startup", "command") == %w[python -m price_refresh --apply] &&
       prod_cron["extraJobs"] == [{ "nameSuffix" => "deliver", "schedule" => "40 11,13 * * *", "command" => %w[python -m price_refresh --deliver] }]
  abort "#{prod_crawler_file}: Prod Crawler의 IRSA·Secret·apply/deliver 일정·자동 실행 설정이 예상과 다릅니다."
end

prod_chat_workloads = {
  "chat-api" => {
    image_group: "be",
    port: 8080,
    termination: 330,
    role: "arn:aws:iam::686496667254:role/lookddak-prod-v3-chat-api",
    parameters: %w[/lookddak/prod/v3/mysql/jdbc-url /lookddak/prod/v3/mysql/app/username /lookddak/prod/v3/mysql/app/password /lookddak/prod/spring/jwt-secret /lookddak/prod/internal/ai-api-key]
  },
  "chat-ai" => {
    image_group: "ai",
    port: 8000,
    termination: 120,
    role: "arn:aws:iam::686496667254:role/lookddak-prod-v3-chat-ai",
    parameters: %w[/lookddak/prod/v3/postgresql/app/database-url /lookddak/prod/v3/postgresql/app/checkpoint-dsn /lookddak/prod/internal/ai-api-key /lookddak/prod/fastapi/runware-llm-api-key /lookddak/prod/fastapi/runware-vton-api-key /lookddak/prod/fastapi/openAI-api-key]
  }
}

prod_chat_workloads.each do |name, expected|
  file = "environments/prod/domains/chat/workloads/#{name}.yaml"
  values = load_yaml(file)
  spread = values.dig("scheduling", "topologySpreadConstraints") || []
  parameters = YAML.safe_load(values.dig("secrets", "parameters", "objects")).map { |object| object.fetch("objectName") }
  probe_paths = %w[startup liveness readiness].map { |probe| values.dig("probes", probe, "httpGet", "path") }
  expected_probe = name == "chat-api" ? ["/actuator/health/liveness", "/actuator/health/liveness", "/actuator/health/readiness"] : ["/health", "/health", "/health"]

  unless values["imageGroup"] == expected.fetch(:image_group) &&
         values["replicaCount"] == 2 &&
         values.dig("container", "port") == expected.fetch(:port) &&
         values.dig("deployment", "terminationGracePeriodSeconds") == expected.fetch(:termination) &&
         values.dig("service") == { "enabled" => true, "port" => 80 } &&
         values.dig("pdb") == { "enabled" => true, "maxUnavailable" => 1 } &&
         values.dig("serviceAccount") == { "create" => true, "roleArn" => expected.fetch(:role) } &&
         values.dig("secrets", "enabled") == true &&
         values.dig("secrets", "rolloutOnChange") == true &&
         parameters == expected.fetch(:parameters) &&
         probe_paths == expected_probe &&
         %w[topology.kubernetes.io/zone kubernetes.io/hostname].all? do |key|
           spread.any? { |rule| rule["topologyKey"] == key && rule["minDomains"] == 2 && rule["whenUnsatisfiable"] == "DoNotSchedule" }
         end
    abort "#{file}: Prod Chat의 이미지·IRSA·Secret·Probe·PDB·AZ/Node 분산 설정이 예상과 다릅니다."
  end
end

prod_chat_api = load_yaml("environments/prod/domains/chat/workloads/chat-api.yaml")
prod_chat_env = prod_chat_api.dig("container", "env") || []
unless prod_chat_env.include?({ "name" => "SPRING_PROFILES_ACTIVE", "value" => "prod,chat-api" }) &&
       prod_chat_env.include?({ "name" => "REDIS_CLUSTER_NODES", "value" => "redis-cache-master.lookddak-redis.svc.cluster.local:6379" }) &&
       prod_chat_env.include?({ "name" => "CHAT_REDIS_ENABLED", "value" => "true" }) &&
       prod_chat_env.include?({ "name" => "MANAGEMENT_HEALTH_REDIS_ENABLED", "value" => "false" }) &&
       prod_chat_env.include?({ "name" => "SPRING_AUTOCONFIGURE_EXCLUDE", "value" => "org.springframework.boot.data.redis.autoconfigure.observation.LettuceObservationAutoConfiguration" }) &&
       prod_chat_env.none? { |entry| %w[REDIS_HOST REDIS_PORT REDIS_PASSWORD].include?(entry["name"]) } &&
       prod_chat_api.dig("routing", "rules", 0, "timeouts", "request") == "0s"
  abort "Prod Chat API는 Redis Cluster 활성 설정과 fallback을 고려한 Health·SSE Route 설정을 사용해야 합니다."
end

prod_fitting_workloads = {
  "fitting-api" => {
    image: "be", port: 8080, termination: 330, service: { "enabled" => true, "port" => 80 },
    role: "arn:aws:iam::686496667254:role/lookddak-prod-v3-fitting-api",
    parameters: %w[/lookddak/prod/v3/mysql/jdbc-url /lookddak/prod/v3/mysql/app/username /lookddak/prod/v3/mysql/app/password /lookddak/prod/spring/jwt-secret /lookddak/prod/internal/ai-api-key /lookddak/prod/v3/s3/images/bucket]
  },
  "fitting-worker" => {
    image: "be", port: 8080, termination: 120, service: { "enabled" => false },
    role: "arn:aws:iam::686496667254:role/lookddak-prod-v3-fitting-worker",
    parameters: %w[/lookddak/prod/v3/mysql/jdbc-url /lookddak/prod/v3/mysql/app/username /lookddak/prod/v3/mysql/app/password /lookddak/prod/spring/jwt-secret /lookddak/prod/v3/sqs/be-fitting-request/url /lookddak/prod/v3/sqs/be-fitting-response/url]
  },
  "vton-orchestrator" => {
    image: "ai", port: 8000, termination: 330, service: { "enabled" => true, "port" => 80 },
    role: "arn:aws:iam::686496667254:role/lookddak-prod-v3-vton-orchestrator",
    parameters: %w[/lookddak/prod/v3/postgresql/app/database-url /lookddak/prod/internal/ai-api-key /lookddak/prod/fastapi/runware-vton-api-key /lookddak/prod/fastapi/runware-llm-api-key /lookddak/prod/fastapi/webhook-token /lookddak/prod/fastapi/virtual-fitting-runware-webhook-url /lookddak/prod/v3/s3/images/bucket /lookddak/prod/v3/sqs/be-fitting-request/url /lookddak/prod/v3/sqs/ai-fitting-response/url /lookddak/prod/v3/sqs/be-fitting-response/url]
  }
}

prod_fitting_workloads.each do |name, expected|
  file = "environments/prod/domains/fitting/workloads/#{name}.yaml"
  values = load_yaml(file)
  spread = values.dig("scheduling", "topologySpreadConstraints") || []
  parameters = YAML.safe_load(values.dig("secrets", "parameters", "objects")).map { |object| object.fetch("objectName") }
  expected_probe = name == "vton-orchestrator" ? ["/health", "/health", "/health"] : ["/actuator/health/liveness", "/actuator/health/liveness", "/actuator/health/readiness"]
  probe_paths = %w[startup liveness readiness].map { |probe| values.dig("probes", probe, "httpGet", "path") }

  unless values["imageGroup"] == expected.fetch(:image) &&
         values["replicaCount"] == 2 &&
         values.dig("container", "port") == expected.fetch(:port) &&
         values.dig("deployment", "terminationGracePeriodSeconds") == expected.fetch(:termination) &&
         values.dig("service") == expected.fetch(:service) &&
         values.dig("pdb") == { "enabled" => true, "maxUnavailable" => 1 } &&
         values.dig("serviceAccount") == { "create" => true, "roleArn" => expected.fetch(:role) } &&
         values.dig("secrets", "enabled") == true &&
         values.dig("secrets", "rolloutOnChange") == true &&
         parameters == expected.fetch(:parameters) &&
         probe_paths == expected_probe &&
         %w[topology.kubernetes.io/zone kubernetes.io/hostname].all? do |key|
           spread.any? { |rule| rule["topologyKey"] == key && rule["minDomains"] == 2 && rule["whenUnsatisfiable"] == "DoNotSchedule" }
         end
    abort "#{file}: Prod Fitting의 이미지·IRSA·Secret·Probe·PDB·AZ/Node 분산 설정이 예상과 다릅니다."
  end
end

prod_fitting_api = load_yaml("environments/prod/domains/fitting/workloads/fitting-api.yaml")
unless prod_fitting_api.dig("container", "env")&.include?({ "name" => "FITTING_OUTBOX_ENABLED", "value" => "false" }) &&
       prod_fitting_api.dig("container", "env")&.include?({ "name" => "FITTING_RESULT_CONSUMER_ENABLED", "value" => "false" }) &&
       prod_fitting_api.dig("routing", "rules", 1, "timeouts", "request") == "0s"
  abort "Prod Fitting API는 Worker 비활성과 알림 SSE 무제한 Route가 필요합니다."
end

prod_fitting_worker = load_yaml("environments/prod/domains/fitting/workloads/fitting-worker.yaml")
unless prod_fitting_worker.dig("container", "env")&.include?({ "name" => "FITTING_OUTBOX_ENABLED", "value" => "true" }) &&
       prod_fitting_worker.dig("container", "env")&.include?({ "name" => "FITTING_RESULT_CONSUMER_ENABLED", "value" => "true" })
  abort "Prod Fitting Worker는 Outbox 발행과 결과 소비를 담당해야 합니다."
end

prod_vton = load_yaml("environments/prod/domains/fitting/workloads/vton-orchestrator.yaml")
unless %w[VIRTUAL_FITTING_REQUEST_WORKER_ENABLED VIRTUAL_FITTING_POSTPROCESS_WORKER_ENABLED VIRTUAL_FITTING_RESULT_PUBLISHER_ENABLED VIRTUAL_FITTING_WATCHDOG_ENABLED].all? do |name|
         prod_vton.dig("container", "env")&.include?({ "name" => name, "value" => "true" })
       end
  abort "Prod VTON Orchestrator는 Queue·후처리·결과 발행·Watchdog 역할을 활성화해야 합니다."
end

prod_project_file = "argocd/projects/lookddak-prod.yaml"
prod_project = load_yaml(prod_project_file)
unless prod_project.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-2" &&
       prod_project.dig("spec", "sourceRepos") == [gitops_repository] &&
       prod_project.dig("spec", "destinations") == [{ "server" => in_cluster_server, "namespace" => "lookddak-*" }]
  abort "#{prod_project_file}: Prod 워크로드 Project의 선행 Wave·Repository·Namespace 범위가 예상과 다릅니다."
end

prod_argocd_project_file = "argocd/projects/lookddak-prod-argocd.yaml"
prod_argocd_project = load_yaml(prod_argocd_project_file)
expected_prod_argocd_resources = [
  { "group" => "apiextensions.k8s.io", "kind" => "CustomResourceDefinition" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRole" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRoleBinding" }
]
unless prod_argocd_project["kind"] == "AppProject" &&
       prod_argocd_project.dig("metadata", "name") == "lookddak-prod-argocd" &&
       prod_argocd_project.dig("metadata", "namespace") == "argocd" &&
       prod_argocd_project.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-2" &&
       prod_argocd_project.dig("spec", "sourceRepos") == [gitops_repository, "https://argoproj.github.io/argo-helm"] &&
       prod_argocd_project.dig("spec", "destinations") == [{ "server" => in_cluster_server, "namespace" => "argocd" }] &&
       prod_argocd_project.dig("spec", "clusterResourceWhitelist") == expected_prod_argocd_resources
  abort "#{prod_argocd_project_file}: Prod Argo CD Project 최소 권한이 예상과 다릅니다."
end

prod_argocd_app_file = "argocd/prod/bootstrap/argocd-application.yaml"
prod_argocd_app = load_yaml(prod_argocd_app_file)
unless prod_argocd_app["kind"] == "Application" &&
       prod_argocd_app.dig("metadata", "name") == "argocd" &&
       prod_argocd_app.dig("metadata", "namespace") == "argocd" &&
       prod_argocd_app.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "1" &&
       prod_argocd_app.dig("spec", "project") == "lookddak-prod-argocd" &&
       prod_argocd_app.dig("spec", "source") == { "repoURL" => gitops_repository, "targetRevision" => "main", "path" => "platform/prod/argocd", "helm" => { "releaseName" => "argocd" } } &&
       prod_argocd_app.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "argocd" } &&
       prod_argocd_app.dig("spec", "syncPolicy", "automated") == expected_root_automation &&
       prod_argocd_app.dig("spec", "syncPolicy", "syncOptions") == ["RespectIgnoreDifferences=true", "PruneLast=true"]
  abort "#{prod_argocd_app_file}: Prod Argo CD 자기관리 설정이 예상과 다릅니다."
end
expected_prod_secret_ignore = [{ "group" => "", "kind" => "Secret", "name" => "argocd-secret", "namespace" => "argocd", "jsonPointers" => ["/data"] }]
abort "#{prod_argocd_app_file}: 런타임 Secret 보호가 필요합니다." unless prod_argocd_app.dig("spec", "ignoreDifferences") == expected_prod_secret_ignore
abort "#{prod_argocd_app_file}: 연쇄 삭제 Finalizer를 추가하면 안 됩니다." unless (prod_argocd_app.dig("metadata", "finalizers") || []).empty?

prod_argocd_chart = load_yaml("platform/prod/argocd/Chart.yaml")
prod_argocd_dependency = prod_argocd_chart.fetch("dependencies").find { |item| item["name"] == "argo-cd" }
unless prod_argocd_dependency && prod_argocd_dependency["version"] == "10.11.6" && prod_argocd_dependency["repository"] == "https://argoproj.github.io/argo-helm"
  abort "Prod Argo CD는 Dev에서 검증한 공식 Chart 10.11.6을 유지해야 합니다."
end
prod_argocd_values = load_yaml("platform/prod/argocd/values.yaml").fetch("argo-cd")
prod_notifications = prod_argocd_values.fetch("notifications")
unless prod_argocd_values.dig("global", "nodeSelector", "lookddak.io/node-pool") == "system" &&
       (prod_argocd_values.dig("global", "tolerations") || []).include?({ "key" => "CriticalAddonsOnly", "operator" => "Equal", "value" => "true", "effect" => "NoSchedule" }) &&
       prod_argocd_values.dig("server", "service", "type") == "ClusterIP" &&
       prod_argocd_values.dig("server", "ingress", "enabled") == false &&
       prod_notifications["enabled"] == true &&
       prod_notifications["argocdUrl"] == "https://argocd.lookddak.com" &&
       prod_notifications.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-prod-argocd-notifications" &&
       prod_notifications.dig("context", "environment") == "prod" &&
       prod_notifications.dig("notifiers", "service.awssqs").include?("queue: lookddak-alert-queue") &&
       prod_notifications.dig("triggers", "trigger.on-deploy-failed").include?("app.status.health.status == 'Degraded'") &&
       prod_notifications.dig("triggers", "trigger.on-deploy-failed").include?("app.status.operationState.phase != 'Running'") &&
       prod_argocd_values.dig("configs", "cm", "admin.enabled") == true
  abort "platform/prod/argocd/values.yaml: System Node 배치와 Prod 실패 알림 설정이 필요합니다."
end

prod_notification_subscription = "lookddak-alert-queue"
%w[lookddak-prod lookddak-prod-platform lookddak-prod-argocd].each do |project_name|
  project = load_yaml("argocd/projects/#{project_name}.yaml")
  unless project.dig("metadata", "annotations", "notifications.argoproj.io/subscribe.on-deploy-failed.awssqs") == prod_notification_subscription
    abort "#{project_name}: Prod 배포 실패 Trigger 구독이 필요합니다."
  end
end

prod_argocd_route_file = "platform/prod/argocd/templates/httproute.yaml"
prod_argocd_route = load_yaml(prod_argocd_route_file)
expected_prod_argocd_parent = [{
  "group" => "gateway.networking.k8s.io",
  "kind" => "Gateway",
  "name" => "lookddak-gateway",
  "namespace" => "istio-ingress",
  "sectionName" => "https-argocd"
}]
expected_prod_argocd_rules = [{ "backendRefs" => [{ "name" => "argocd-server", "port" => 80 }] }]
unless prod_argocd_route["apiVersion"] == "gateway.networking.k8s.io/v1" &&
       prod_argocd_route["kind"] == "HTTPRoute" &&
       prod_argocd_route.dig("metadata", "name") == "argocd-server" &&
       prod_argocd_route.dig("metadata", "namespace") == "argocd" &&
       prod_argocd_route.dig("spec", "parentRefs") == expected_prod_argocd_parent &&
       prod_argocd_route.dig("spec", "hostnames") == ["argocd.lookddak.com"] &&
       prod_argocd_route.dig("spec", "rules") == expected_prod_argocd_rules
  abort "#{prod_argocd_route_file}: Prod Argo CD Gateway·Hostname·Backend 계약이 예상과 다릅니다."
end

prod_namespace_documents = YAML.load_stream(File.read("argocd/prod/bootstrap/namespaces.yaml")).compact
expected_prod_namespaces = %w[argocd istio-ingress istio-system lookddak-chat lookddak-commerce lookddak-fitting lookddak-identity lookddak-redis lookddak-web monitoring]
actual_prod_namespaces = prod_namespace_documents.map { |item| item.dig("metadata", "name") }.sort
abort "Prod Bootstrap Namespace 구성이 예상과 다릅니다." unless actual_prod_namespaces == expected_prod_namespaces
prod_namespace_documents.each do |namespace|
  unless namespace["kind"] == "Namespace" &&
         namespace.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-1" &&
         namespace.dig("metadata", "annotations", "argocd.argoproj.io/sync-options") == "Prune=false"
    abort "#{namespace.dig('metadata', 'name')}: Namespace 선행 생성·삭제 보호 설정이 필요합니다."
  end
end
prod_namespace_documents.select { |item| item.dig("metadata", "name")&.start_with?("lookddak-") }.each do |namespace|
  abort "#{namespace.dig('metadata', 'name')}: 향후 Ambient 등록 Label이 필요합니다." unless namespace.dig("metadata", "labels", "istio.io/dataplane-mode") == "ambient"
end

prod_platform_project_file = "argocd/projects/lookddak-prod-platform.yaml"
prod_platform_project = load_yaml(prod_platform_project_file)
expected_prod_platform_repos = [
  gitops_repository,
  "https://aws.github.io/eks-charts",
  "https://aws.github.io/secrets-store-csi-driver-provider-aws",
  "https://blob.istio.io/istio-release/charts",
  "https://charts.jetstack.io",
  "https://grafana-community.github.io/helm-charts",
  "https://grafana.github.io/helm-charts",
  "https://kubernetes-sigs.github.io/metrics-server/",
  "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts",
  "https://ot-container-kit.github.io/helm-charts",
  "https://prometheus-community.github.io/helm-charts",
  "oci://public.ecr.aws/karpenter"
]
expected_prod_platform_destinations = %w[kube-system istio-system istio-ingress lookddak-redis monitoring].map do |namespace|
  { "server" => in_cluster_server, "namespace" => namespace }
end
expected_prod_platform_resources = [
  { "group" => "apiextensions.k8s.io", "kind" => "CustomResourceDefinition" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRole" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRoleBinding" },
  { "group" => "apiregistration.k8s.io", "kind" => "APIService" },
  { "group" => "storage.k8s.io", "kind" => "CSIDriver" },
  { "group" => "storage.k8s.io", "kind" => "StorageClass" },
  { "group" => "scheduling.k8s.io", "kind" => "PriorityClass" },
  { "group" => "admissionregistration.k8s.io", "kind" => "MutatingWebhookConfiguration" },
  { "group" => "admissionregistration.k8s.io", "kind" => "ValidatingWebhookConfiguration" },
  { "group" => "admissionregistration.k8s.io", "kind" => "ValidatingAdmissionPolicy" },
  { "group" => "admissionregistration.k8s.io", "kind" => "ValidatingAdmissionPolicyBinding" },
  { "group" => "cert-manager.io", "kind" => "ClusterIssuer" },
  { "group" => "cilium.io", "kind" => "CiliumClusterwideNetworkPolicy" },
  { "group" => "karpenter.k8s.aws", "kind" => "EC2NodeClass" },
  { "group" => "karpenter.sh", "kind" => "NodePool" }
]
unless prod_platform_project.dig("metadata", "name") == "lookddak-prod-platform" &&
       prod_platform_project.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-2" &&
       prod_platform_project.dig("spec", "sourceRepos") == expected_prod_platform_repos &&
       prod_platform_project.dig("spec", "destinations") == expected_prod_platform_destinations &&
       prod_platform_project.dig("spec", "clusterResourceWhitelist") == expected_prod_platform_resources
  abort "#{prod_platform_project_file}: Prod 플랫폼 Project의 Repository·Namespace·Cluster Resource 범위가 예상과 다릅니다."
end

prod_platform_applications = {
  "karpenter-crd" => ["platform/prod/karpenter/crd", "kube-system", "-1"],
  "karpenter-controller" => ["platform/prod/karpenter/controller", "kube-system", "0"],
  "karpenter-nodepool" => ["platform/prod/karpenter/nodepool", "kube-system", "1"],
  "metrics-server" => ["platform/prod/metrics-server", "kube-system", "0"],
  "secrets-store-csi-driver" => ["platform/prod/secrets-store-csi/driver", "kube-system", "-1"],
  "secrets-store-csi-provider-aws" => ["platform/prod/secrets-store-csi/provider-aws", "kube-system", "0"],
  "aws-load-balancer-controller" => ["platform/prod/networking/aws-load-balancer-controller", "kube-system", "0"],
  "cert-manager" => ["platform/prod/cert-manager/controller", "kube-system", "0"],
  "cert-manager-issuers" => ["platform/prod/cert-manager/issuers", "kube-system", "1"],
  "gateway-api-crds" => ["platform/dev/networking/gateway-api/crds", "kube-system", "-1"],
  "istio-base" => ["platform/prod/networking/istio/base", "istio-system", "-1"],
  "istiod" => ["platform/prod/networking/istio/istiod", "istio-system", "0"],
  "istio-cni" => ["platform/prod/networking/istio/cni", "istio-system", "1"],
  "ztunnel" => ["platform/prod/networking/istio/ztunnel", "istio-system", "2"],
  "istio-gateway" => ["platform/prod/networking/gateway", "istio-ingress", "3"],
  "network-policies" => ["platform/prod/networking/policies", "kube-system", "3"],
  "mesh-security" => ["platform/prod/networking/mesh-security", "istio-system", "3"]
}
prod_platform_applications.each do |component, (path, namespace, wave)|
  file = "argocd/prod/platform/#{component}-application.yaml"
  application = load_yaml(file)
  expected_automation = expected_root_automation.merge("prune" => component != "gateway-api-crds")
  unless application.dig("metadata", "name") == "lookddak-prod-#{component}" &&
         application.dig("metadata", "namespace") == "argocd" &&
         application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == wave &&
         application.dig("spec", "project") == "lookddak-prod-platform" &&
         application.dig("spec", "source", "repoURL") == gitops_repository &&
         application.dig("spec", "source", "targetRevision") == "main" &&
         application.dig("spec", "source", "path") == path &&
         application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => namespace } &&
         application.dig("spec", "syncPolicy", "automated") == expected_automation
    abort "#{file}: Prod 플랫폼 Application 신원·경로·Sync Wave가 예상과 다릅니다."
  end
end

prod_internal_application_file = "argocd/prod/platform/internal-api-application.yaml"
prod_internal_application = load_yaml(prod_internal_application_file)
unless prod_internal_application.dig("metadata", "name") == "lookddak-prod-internal-api" &&
       prod_internal_application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "4" &&
       prod_internal_application.dig("spec", "project") == "lookddak-prod" &&
       prod_internal_application.dig("spec", "source", "path") == "platform/prod/networking/internal-api" &&
       prod_internal_application.dig("spec", "source", "targetRevision") == "main" &&
       prod_internal_application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-web" } &&
       prod_internal_application.dig("spec", "syncPolicy", "automated") == expected_root_automation
  abort "#{prod_internal_application_file}: Prod 내부 API Application 신원·경로·자동 동기화 설정이 예상과 다릅니다."
end

prod_domain_namespaces = %w[lookddak-chat lookddak-commerce lookddak-fitting lookddak-identity lookddak-web]
prod_baseline = load_yaml("platform/prod/networking/policies/domain-baseline.yaml")
unless prod_baseline["kind"] == "CiliumClusterwideNetworkPolicy" &&
       prod_baseline.dig("metadata", "name") == "lookddak-prod-domain-baseline" &&
       prod_baseline.dig("spec", "endpointSelector", "matchExpressions") == [{ "key" => "k8s:io.cilium.k8s.namespace.labels.lookddak.com/domain", "operator" => "Exists" }] &&
       prod_baseline.dig("spec", "ingress").any? { |rule| rule["fromCIDR"] == ["169.254.7.127/32"] } &&
       prod_baseline.dig("spec", "egress").any? { |rule| (rule["toPorts"] || []).any? { |port| port.dig("rules", "dns") } }
  abort "Prod 도메인 baseline은 기본 차단 후 Ambient probe·Gateway·DNS만 공통 허용해야 합니다."
end

prod_same_namespace_targets = YAML.load_stream(File.read("platform/prod/networking/policies/domain-same-namespace.yaml")).compact.map do |policy|
  namespace = policy.dig("spec", "endpointSelector", "matchLabels", "k8s:io.kubernetes.pod.namespace")
  peers = (policy.dig("spec", "ingress") || []) + (policy.dig("spec", "egress") || [])
  unless peers.length == 2 && peers.all? { |rule| ((rule["fromEndpoints"] || rule["toEndpoints"]) || []) == [{ "matchLabels" => { "k8s:io.kubernetes.pod.namespace" => namespace } }] }
    abort "#{policy.dig('metadata', 'name')}: Prod 정책은 같은 Namespace의 HBONE 통신만 허용해야 합니다."
  end
  namespace
end.sort
abort "Prod 도메인별 same-namespace 정책이 필요합니다." unless prod_same_namespace_targets == prod_domain_namespaces.sort

prod_workload_namespaces = Dir["environments/prod/domains/*/workloads/*.yaml"].to_h do |file|
  [File.basename(file, ".yaml"), "lookddak-#{file.split('/')[3]}"]
end
prod_egress_files = Dir["platform/prod/networking/policies/*-egress.yaml"].sort.reject { |file| file.end_with?("web-waypoint.yaml") }
abort "Prod 10개 워크로드마다 egress 정책이 필요합니다." unless prod_egress_files.length == prod_workload_namespaces.length
prod_egress_files.each do |file|
  workload = File.basename(file, "-egress.yaml")
  policy = load_yaml(file)
  expected_selector = { "k8s:io.kubernetes.pod.namespace" => prod_workload_namespaces[workload], "k8s:app.kubernetes.io/name" => workload }
  unless policy["kind"] == "CiliumClusterwideNetworkPolicy" &&
         policy.dig("metadata", "name") == "lookddak-prod-#{workload}-egress" &&
         policy.dig("spec", "endpointSelector", "matchLabels") == expected_selector &&
         (policy.dig("spec", "egress") || []).all? { |rule| rule["toFQDNs"] && rule.keys.sort == %w[toFQDNs toPorts] }
    abort "#{file}: Prod egress는 해당 워크로드만 선택하고 FQDN·Port만 허용해야 합니다."
  end
end

prod_peer_authentication = load_yaml("platform/prod/networking/mesh-security/peer-authentication.yaml")
unless prod_peer_authentication.dig("metadata", "name") == "default" &&
       prod_peer_authentication.dig("metadata", "namespace") == "istio-system" &&
       prod_peer_authentication.dig("spec", "mtls", "mode") == "STRICT"
  abort "Prod Ambient 메시 전체에 mTLS STRICT가 필요합니다."
end

Dir["environments/prod/domains/*/domain.yaml"].each do |file|
  abort "#{file}: Prod 도메인은 Istio 인가 기본값이 필요합니다." unless load_yaml(file).dig("authorizationPolicy", "enabled") == true
end

prod_internal_route = load_yaml("platform/prod/networking/internal-api/api-httproute.yaml")
prod_internal_backends = prod_internal_route.dig("spec", "rules").flat_map { |rule| rule["backendRefs"].map { |ref| ref["namespace"] } }.uniq.sort
prod_grant_namespaces = YAML.load_stream(File.read("platform/prod/networking/internal-api/reference-grants.yaml")).compact.map { |grant| grant.dig("metadata", "namespace") }.sort
abort "Prod 내부 API backend마다 ReferenceGrant가 필요합니다." unless prod_internal_backends == prod_grant_namespaces
prod_sse_rules = prod_internal_route.dig("spec", "rules").select { |rule| rule.dig("timeouts", "request") == "0s" }
abort "Prod 내부 Chat·Fitting SSE 경로에는 request timeout 비활성화가 필요합니다." unless prod_sse_rules.length == 2

prod_public_routes = {
  "environments/prod/domains/web/workloads/web-bff.yaml" => [["/"]],
  "environments/prod/domains/identity/workloads/identity-api.yaml" => [["/api/v1/auth", "/api/v1/members", "/api/v1/full-body-image"]],
  "environments/prod/domains/commerce/workloads/commerce-api.yaml" => [["/api/v1/products", "/api/v1/wishlists"]],
  "environments/prod/domains/chat/workloads/chat-api.yaml" => [["/api/v1/chat-rooms"]],
  "environments/prod/domains/fitting/workloads/fitting-api.yaml" => [["/api/v1/fitting-candidates", "/api/v1/fitting-jobs", "/api/v1/fitting-results"], ["/api/v1/notifications"]],
  "environments/prod/domains/fitting/workloads/vton-orchestrator.yaml" => [["/api/v2/webhooks/runware"]]
}
expected_prod_route_parents = [
  { "group" => "gateway.networking.k8s.io", "kind" => "Gateway", "name" => "lookddak-gateway", "namespace" => "istio-ingress", "sectionName" => "https-v3-prod" }
]
prod_public_routes.each do |file, expected_paths|
  routing = load_yaml(file).fetch("routing")
  actual_paths = routing.fetch("rules").map { |rule| rule.fetch("matches").map { |match| match.dig("path", "value") } }
  unless routing["enabled"] == true &&
         load_yaml(file).dig("service", "port") == 80 &&
         routing["parentRefs"] == expected_prod_route_parents &&
         routing["hostnames"] == ["v3-prod.lookddak.com"] &&
         actual_paths == expected_paths
    abort "#{file}: Prod 검증 Route는 Gateway의 https-v3-prod와 v3-prod.lookddak.com만 사용해야 합니다."
  end
end

prod_chat_route = load_yaml("environments/prod/domains/chat/workloads/chat-api.yaml").dig("routing", "rules", 0)
prod_fitting_notification_route = load_yaml("environments/prod/domains/fitting/workloads/fitting-api.yaml").dig("routing", "rules", 1)
unless prod_chat_route.dig("timeouts", "request") == "0s" && prod_fitting_notification_route.dig("timeouts", "request") == "0s"
  abort "Prod Chat·Fitting 알림 SSE Route는 request timeout을 비활성화해야 합니다."
end

%w[body-image-validator chat-ai fitting-worker price-crawler].each do |workload|
  file = Dir["environments/prod/domains/*/workloads/#{workload}.yaml"].first
  abort "#{file}: 외부 진입점이 아닌 워크로드는 Route를 만들지 않습니다." unless load_yaml(file).dig("routing", "enabled") == false
end

prod_karpenter_values = load_yaml("platform/prod/karpenter/controller/values.yaml").fetch("karpenter")
unless prod_karpenter_values.dig("settings", "clusterName") == "lookddak-prod" &&
       prod_karpenter_values.dig("serviceAccount", "name") == "karpenter" &&
       prod_karpenter_values.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-prod-karpenter-controller" &&
       prod_karpenter_values["replicas"] == 2 &&
       prod_karpenter_values.dig("nodeSelector", "lookddak.io/node-pool") == "system"
  abort "Prod Karpenter Controller의 Cluster·IRSA·System Node 배치가 예상과 다릅니다."
end

prod_nodeclass = load_yaml("platform/prod/karpenter/nodepool/ec2-nodeclass.yaml")
unless prod_nodeclass.dig("spec", "instanceProfile") == "lookddak-prod-karpenter-node" &&
       prod_nodeclass.dig("spec", "securityGroupSelectorTerms") == [{ "id" => "sg-041f092dc1698a99a" }] &&
       prod_nodeclass.dig("spec", "subnetSelectorTerms") == [{ "tags" => { "karpenter.sh/discovery" => "lookddak-prod", "Tier" => "private-node" } }] &&
       prod_nodeclass.dig("spec", "associatePublicIPAddress") == false &&
       prod_nodeclass.dig("spec", "metadataOptions", "httpTokens") == "required"
  abort "Prod EC2NodeClass의 Instance Profile·Subnet·Cluster SG·IMDSv2 설정이 예상과 다릅니다."
end

prod_nodepool = load_yaml("platform/prod/karpenter/nodepool/nodepool.yaml")
prod_requirements = (prod_nodepool.dig("spec", "template", "spec", "requirements") || []).to_h { |item| [item["key"], item["values"]] }
unless prod_requirements["kubernetes.io/arch"] == ["arm64"] &&
       prod_requirements["karpenter.sh/capacity-type"] == ["on-demand"] &&
       prod_requirements["topology.kubernetes.io/zone"] == %w[ap-northeast-2a ap-northeast-2c] &&
       prod_nodepool.dig("spec", "limits") == { "cpu" => "64", "memory" => "128Gi" } &&
       prod_nodepool.dig("spec", "disruption", "consolidationPolicy") == "WhenEmptyOrUnderutilized" &&
       prod_nodepool.dig("spec", "disruption", "budgets") == [{ "nodes" => "1" }]
  abort "Prod NodePool은 ARM64 On-Demand·2AZ·안전한 통합 제한을 유지해야 합니다."
end

prod_metrics = load_yaml("platform/prod/metrics-server/values.yaml").fetch("metrics-server")
unless prod_metrics["replicas"] == 2 &&
       prod_metrics.dig("nodeSelector", "lookddak.io/node-pool") == "system" &&
       prod_metrics.dig("podDisruptionBudget", "minAvailable") == 1
  abort "Prod Metrics Server는 System Node에 2개와 PDB를 유지해야 합니다."
end

prod_csi = load_yaml("platform/prod/secrets-store-csi/driver/values.yaml").fetch("secrets-store-csi-driver")
prod_ascp = load_yaml("platform/prod/secrets-store-csi/provider-aws/values.yaml").fetch("secrets-store-csi-driver-provider-aws")
unless (prod_csi.dig("linux", "tolerations") || []).include?({ "operator" => "Exists" }) &&
       prod_csi.dig("syncSecret", "enabled") == false &&
       prod_csi["enableSecretRotation"] == true &&
       prod_csi["rotationPollInterval"] == "1h" &&
       prod_ascp["awsRegion"] == "ap-northeast-2" &&
       prod_ascp.dig("secrets-store-csi-driver", "install") == false &&
       prod_ascp["driverWritesSecrets"] == false
  abort "Prod CSI·ASCP는 전체 Linux Node 배치, Secret 비복제와 Rotation을 유지해야 합니다."
end

prod_lbc = load_yaml("platform/prod/networking/aws-load-balancer-controller/values.yaml").fetch("aws-load-balancer-controller")
unless prod_lbc["clusterName"] == "lookddak-prod" &&
       prod_lbc["vpcId"] == "vpc-00846a80381ac4f45" &&
       prod_lbc.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-prod-aws-load-balancer-controller" &&
       prod_lbc.dig("nodeSelector", "lookddak.io/node-pool") == "system" &&
       prod_lbc["defaultTargetType"] == "ip"
  abort "Prod AWS Load Balancer Controller의 Cluster·VPC·IRSA·Pod IP Target 설정이 예상과 다릅니다."
end

prod_cert_manager = load_yaml("platform/prod/cert-manager/controller/values.yaml").fetch("cert-manager")
unless prod_cert_manager.dig("crds", "enabled") == true &&
       prod_cert_manager.dig("crds", "keep") == true &&
       prod_cert_manager.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-prod-cert-manager" &&
       prod_cert_manager.dig("nodeSelector", "lookddak.io/node-pool") == "system"
  abort "Prod cert-manager의 CRD 보호·IRSA·System Node 배치가 예상과 다릅니다."
end

prod_istio_versions = %w[base istiod cni ztunnel].map do |chart|
  dependency = load_yaml("platform/prod/networking/istio/#{chart}/Chart.yaml").fetch("dependencies").first
  [dependency["name"], dependency["version"], dependency["repository"]]
end
unless prod_istio_versions.all? { |_, version, repository| version == "1.31.3" && repository == "https://blob.istio.io/istio-release/charts" }
  abort "Prod Istio base·istiod·CNI·ztunnel은 공식 Chart 1.31.3을 함께 사용해야 합니다."
end
prod_istiod = load_yaml("platform/prod/networking/istio/istiod/values.yaml").fetch("istiod")
unless prod_istiod["profile"] == "ambient" && prod_istiod["autoscaleMin"] == 2 && prod_istiod.dig("nodeSelector", "lookddak.io/node-pool") == "system"
  abort "Prod istiod는 Ambient·System Node·최소 2개 구성이 필요합니다."
end

prod_gateway = load_yaml("platform/prod/networking/gateway/gateway.yaml")
gateway_annotations = prod_gateway.dig("spec", "infrastructure", "annotations") || {}
gateway_listeners = prod_gateway.dig("spec", "listeners") || []
gateway_hostnames = gateway_listeners.map { |listener| listener["hostname"] }
unless prod_gateway.dig("spec", "gatewayClassName") == "istio" &&
       gateway_annotations["service.beta.kubernetes.io/aws-load-balancer-scheme"] == "internal" &&
       gateway_annotations["service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"] == "ip" &&
       gateway_annotations["service.beta.kubernetes.io/aws-load-balancer-security-groups"] == "sg-0993a57cec9f3b5f5" &&
       gateway_annotations["service.beta.kubernetes.io/aws-load-balancer-manage-backend-security-group-rules"] == "true" &&
       !gateway_annotations.key?("service.beta.kubernetes.io/load-balancer-source-ranges") &&
       gateway_hostnames == %w[lookddak.com www.lookddak.com v3-prod.lookddak.com argocd.lookddak.com grafana.v3-prod.lookddak.com]
  abort "Prod Gateway는 내부 NLB·Pod IP·CloudFront 전용 SG·승인된 Hostname을 유지해야 합니다."
end
prod_validation_listener = gateway_listeners.find { |listener| listener["name"] == "https-v3-prod" }
expected_domain_route_selector = {
  "namespaces" => {
    "from" => "Selector",
    "selector" => {
      "matchExpressions" => [
        { "key" => "lookddak.com/domain", "operator" => "Exists" }
      ]
    }
  }
}
unless prod_validation_listener &&
       prod_validation_listener["port"] == 443 &&
       prod_validation_listener["protocol"] == "HTTPS" &&
       prod_validation_listener["hostname"] == "v3-prod.lookddak.com" &&
       prod_validation_listener.dig("tls", "mode") == "Terminate" &&
       prod_validation_listener.dig("tls", "certificateRefs") == [
         { "group" => "", "kind" => "Secret", "name" => "lookddak-com-tls" }
       ] &&
       prod_validation_listener["allowedRoutes"] == expected_domain_route_selector
  abort "Prod 검증 Listener는 HTTPS 443·공용 TLS Secret·Domain Namespace Selector를 유지해야 합니다."
end
gateway_options = load_yaml("platform/prod/networking/gateway/gateway-options.yaml").dig("data", "deployment").to_s
unless gateway_options.include?("replicas: 2") &&
       gateway_options.include?("lookddak.io/node-pool: general-purpose") &&
       gateway_options.include?("topology.kubernetes.io/zone") &&
       gateway_options.include?("whenUnsatisfiable: DoNotSchedule")
  abort "Prod Gateway Pod 2개는 Application Node의 서로 다른 AZ에 강제 배치해야 합니다."
end
prod_certificate = load_yaml("platform/prod/networking/gateway/certificate.yaml")
unless prod_certificate.dig("spec", "issuerRef", "name") == "letsencrypt-prod" &&
       prod_certificate.dig("spec", "secretName") == "lookddak-com-tls" &&
       prod_certificate.dig("spec", "dnsNames") == %w[lookddak.com www.lookddak.com v3-prod.lookddak.com argocd.lookddak.com grafana.v3-prod.lookddak.com]
  abort "Prod Gateway 인증서는 승인된 Prod Issuer·도메인을 사용해야 합니다."
end

platform_project_file = "argocd/projects/lookddak-dev-platform.yaml"
platform_project = load_yaml(platform_project_file)
abort "#{platform_project_file}: kind가 AppProject가 아닙니다." unless platform_project["kind"] == "AppProject"
abort "#{platform_project_file}: Project 이름이 예상과 다릅니다." unless platform_project.dig("metadata", "name") == "lookddak-dev-platform"
unless platform_project.dig("spec", "sourceRepos") == expected_source_repos.call("lookddak-dev-platform")
  abort "#{platform_project_file}: 허용 Repository는 GitOps 저장소와 플랫폼 Application Chart 의존성 저장소와 정확히 같아야 합니다. 예상=#{expected_source_repos.call('lookddak-dev-platform')}, 실제=#{platform_project.dig('spec', 'sourceRepos')}"
end

platform_destinations = platform_project.dig("spec", "destinations")
unless platform_destinations == %w[kube-system istio-system istio-ingress lookddak-redis monitoring].map { |namespace| { "server" => in_cluster_server, "namespace" => namespace } }
  abort "#{platform_project_file}: 플랫폼 배포 대상은 현재 Cluster의 kube-system·istio-system·istio-ingress·lookddak-redis·monitoring Namespace여야 합니다."
end

expected_platform_resources = [
  { "group" => "apiextensions.k8s.io", "kind" => "CustomResourceDefinition" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRole" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRoleBinding" },
  { "group" => "apiregistration.k8s.io", "kind" => "APIService" },
  { "group" => "storage.k8s.io", "kind" => "CSIDriver" },
  { "group" => "storage.k8s.io", "kind" => "StorageClass" },
  { "group" => "scheduling.k8s.io", "kind" => "PriorityClass" },
  { "group" => "admissionregistration.k8s.io", "kind" => "MutatingWebhookConfiguration" },
  { "group" => "admissionregistration.k8s.io", "kind" => "ValidatingWebhookConfiguration" },
  { "group" => "admissionregistration.k8s.io", "kind" => "ValidatingAdmissionPolicy" },
  { "group" => "admissionregistration.k8s.io", "kind" => "ValidatingAdmissionPolicyBinding" },
  { "group" => "cert-manager.io", "kind" => "ClusterIssuer" },
  { "group" => "cilium.io", "kind" => "CiliumClusterwideNetworkPolicy" },
  { "group" => "karpenter.k8s.aws", "kind" => "EC2NodeClass" },
  { "group" => "karpenter.sh", "kind" => "NodePool" }
]
unless platform_project.dig("spec", "clusterResourceWhitelist") == expected_platform_resources
  abort "#{platform_project_file}: 승인된 플랫폼 Cluster 범위 리소스만 허용해야 합니다."
end

unless platform_project.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-2"
  abort "#{platform_project_file}: 플랫폼 Application 전에 적용할 sync-wave -2가 필요합니다."
end
unless platform_project.dig("metadata", "annotations", notification_subscription) == notification_queue
  abort "#{platform_project_file}: 플랫폼 배포 실패 SQS 구독이 필요합니다."
end

image_workflow = File.read(".github/workflows/update-dev-image.yaml")
%w[source-repository source-sha source-actions image-key digest].each do |field|
  abort "자동 이미지 Merge commit에 #{field} 메타데이터가 필요합니다." unless image_workflow.scan("#{field}:").length >= 2
end
unless image_workflow.include?('--subject "chore(dev): $IMAGE_KEY 이미지 digest 갱신"') &&
       image_workflow.include?('--body "$MERGE_BODY"')
  abort "자동 이미지 Squash Merge에서 배포 추적 메타데이터를 보존해야 합니다."
end

prod_image_workflow = File.read(".github/workflows/promote-prod-image.yaml")
%w[source-repository source-sha source-actions image-key digest].each do |field|
  abort "Prod 자동 승격 Merge commit에 #{field} 메타데이터가 필요합니다." unless prod_image_workflow.scan("#{field}:").length >= 2
end
unless prod_image_workflow.include?("types: [prod-image-published]") &&
       prod_image_workflow.include?("repos/$SOURCE_REPOSITORY/compare/$SOURCE_SHA...main") &&
       prod_image_workflow.include?('changed_files[0]}" != "environments/prod/images.yaml"') &&
       prod_image_workflow.include?('--subject "chore(prod): $IMAGE_KEY 이미지 digest 승격"') &&
       prod_image_workflow.include?('--body "$MERGE_BODY"')
  abort "Prod 이미지 승격은 main Commit·단일 Prod images.yaml 변경·추적 가능한 Auto Merge를 보장해야 합니다."
end

istio_version = "1.31.3"
istio_charts.each do |chart|
  chart_file = "platform/dev/networking/istio/#{chart}/Chart.yaml"
  dependency = (load_yaml(chart_file)["dependencies"] || []).find { |item| item["name"] == chart }
  unless dependency && dependency["version"] == istio_version && dependency["repository"] == "https://blob.istio.io/istio-release/charts"
    abort "#{chart_file}: Istio 공식 #{chart} Chart #{istio_version} 의존성을 고정해야 합니다."
  end
end
%w[istiod cni].each do |chart|
  values = load_yaml("platform/dev/networking/istio/#{chart}/values.yaml").fetch(chart)
  abort "Istio #{chart}는 ambient profile을 사용해야 합니다." unless values["profile"] == "ambient"
end
istio_base_values = load_yaml("platform/dev/networking/istio/base/values.yaml").fetch("base")
unless istio_base_values.dig("base", "validationFailurePolicy") == "Fail"
  abort "Istio base는 istiod-default-validator 반복 diff 방지를 위해 validationFailurePolicy Fail이 필요합니다."
end
istiod_values = load_yaml("platform/dev/networking/istio/istiod/values.yaml").fetch("istiod")
unless istiod_values.dig("nodeSelector", "lookddak.io/node-pool") == "system" &&
       (istiod_values["tolerations"] || []).any? { |item| item["key"] == "CriticalAddonsOnly" } &&
       istiod_values.dig("base", "validationFailurePolicy") == "Fail"
  abort "istiod는 System Node 배치, CriticalAddonsOnly Toleration, validationFailurePolicy Fail이 필요합니다."
end

istio_applications = {
  "argocd/dev/gateway-api-crds-application.yaml" => { "name" => "lookddak-dev-gateway-api-crds", "path" => "platform/dev/networking/gateway-api/crds", "namespace" => "kube-system", "wave" => "-1" },
  "argocd/dev/istio-base-application.yaml" => { "name" => "lookddak-dev-istio-base", "path" => "platform/dev/networking/istio/base", "namespace" => "istio-system", "wave" => "-1" },
  "argocd/dev/istiod-application.yaml" => { "name" => "lookddak-dev-istiod", "path" => "platform/dev/networking/istio/istiod", "namespace" => "istio-system", "wave" => "0" },
  "argocd/dev/istio-cni-application.yaml" => { "name" => "lookddak-dev-istio-cni", "path" => "platform/dev/networking/istio/cni", "namespace" => "istio-system", "wave" => "1" },
  "argocd/dev/ztunnel-application.yaml" => { "name" => "lookddak-dev-ztunnel", "path" => "platform/dev/networking/istio/ztunnel", "namespace" => "istio-system", "wave" => "1" }
}
istio_applications.each do |file, expected|
  application = load_yaml(file)
  abort "#{file}: Application 이름이 예상과 다릅니다." unless application.dig("metadata", "name") == expected["name"]
  abort "#{file}: 플랫폼 AppProject를 사용해야 합니다." unless application.dig("spec", "project") == "lookddak-dev-platform"
  abort "#{file}: sync-wave가 예상과 다릅니다." unless application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == expected["wave"]
  abort "#{file}: Public GitOps Repository의 main을 추적해야 합니다." unless application.dig("spec", "source", "repoURL") == gitops_repository && application.dig("spec", "source", "targetRevision") == "main"
  abort "#{file}: 경로가 예상과 다릅니다." unless application.dig("spec", "source", "path") == expected["path"]
  abort "#{file}: 배포 대상이 예상과 다릅니다." unless application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => expected["namespace"] }
end
gateway_crd_application = load_yaml("argocd/dev/gateway-api-crds-application.yaml")
unless gateway_crd_application.dig("spec", "syncPolicy", "automated", "prune") == false &&
       (gateway_crd_application.dig("spec", "syncPolicy", "syncOptions") || []).include?("ServerSideApply=true")
  abort "Gateway API CRD Application은 자동 Prune을 끄고 ServerSideApply를 사용해야 합니다."
end
%w[argocd/dev/istio-base-application.yaml argocd/dev/istiod-application.yaml].each do |file|
  application = load_yaml(file)
  ignored = (application.dig("spec", "ignoreDifferences") || []).map { |item| item["kind"] }.sort
  unless ignored == %w[MutatingWebhookConfiguration ValidatingWebhookConfiguration] &&
         (application.dig("spec", "syncPolicy", "syncOptions") || []).include?("RespectIgnoreDifferences=true")
    abort "#{file}: istiod가 채우는 Webhook caBundle ignoreDifferences와 RespectIgnoreDifferences가 필요합니다."
  end
end

cert_manager_dependency = (load_yaml("platform/dev/cert-manager/controller/Chart.yaml")["dependencies"] || []).find { |item| item["name"] == "cert-manager" }
unless cert_manager_dependency && cert_manager_dependency["version"] == "v1.21.3" && cert_manager_dependency["repository"] == "https://charts.jetstack.io"
  abort "cert-manager 공식 Chart v1.21.3 의존성을 고정해야 합니다."
end
cert_manager_values = load_yaml("platform/dev/cert-manager/controller/values.yaml").fetch("cert-manager")
unless cert_manager_values.dig("serviceAccount", "name") == "cert-manager" &&
       cert_manager_values.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-dev-cert-manager" &&
       cert_manager_values.dig("crds", "enabled") == true && cert_manager_values.dig("crds", "keep") == true
  abort "cert-manager는 IRSA ServiceAccount 연결과 CRD 설치·유지 설정이 필요합니다."
end
%w[nodeSelector].each do |key|
  [cert_manager_values, cert_manager_values["webhook"], cert_manager_values["cainjector"]].each do |component|
    abort "cert-manager 구성요소는 System Node에 배치해야 합니다." unless component.dig(key, "lookddak.io/node-pool") == "system"
  end
end
issuer_documents = YAML.load_stream(File.read("platform/dev/cert-manager/issuers/cluster-issuers.yaml"))
issuer_names = issuer_documents.map { |item| item.dig("metadata", "name") }.sort
abort "ClusterIssuer는 letsencrypt-staging·letsencrypt-prod 2개여야 합니다." unless issuer_names == %w[letsencrypt-prod letsencrypt-staging]
issuer_documents.each do |issuer|
  abort "ClusterIssuer는 kind ClusterIssuer여야 합니다." unless issuer["kind"] == "ClusterIssuer"
  solvers = issuer.dig("spec", "acme", "solvers") || []
  unless solvers.all? { |solver| solver.dig("dns01", "route53") && !solver.dig("dns01", "route53").key?("accessKeyID") && !solver.dig("dns01", "route53").key?("secretAccessKeySecretRef") }
    abort "ClusterIssuer는 Route53 DNS-01을 IRSA로만 사용해야 합니다 (Access Key 금지)."
  end
end

gateway_file = "platform/dev/networking/gateway/gateway.yaml"
gateway = load_yaml(gateway_file)
gateway_annotations = gateway.dig("spec", "infrastructure", "annotations") || {}
unless gateway.dig("metadata", "namespace") == "istio-ingress" && gateway.dig("spec", "gatewayClassName") == "istio"
  abort "#{gateway_file}: istio-ingress Namespace와 istio GatewayClass를 사용해야 합니다."
end
unless gateway_annotations["service.beta.kubernetes.io/aws-load-balancer-scheme"] == "internal" &&
       gateway_annotations["service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"] == "ip" &&
       gateway_annotations["service.beta.kubernetes.io/aws-load-balancer-backend-protocol"] == "tcp" &&
       !gateway_annotations.key?("service.beta.kubernetes.io/aws-load-balancer-ssl-cert")
  abort "#{gateway_file}: 내부 NLB(IP Target)로 TCP 통과해야 하며 NLB에서 TLS를 종료하면 안 됩니다."
end
unless gateway_annotations["service.beta.kubernetes.io/aws-load-balancer-security-groups"].to_s.match?(/\Asg-[0-9a-f]+\z/) &&
       gateway_annotations["service.beta.kubernetes.io/aws-load-balancer-manage-backend-security-group-rules"] == "true"
  abort "#{gateway_file}: NLB에는 CloudFront 전용 SG 1개를 지정하고 Backend SG 규칙은 LB Controller가 관리해야 합니다."
end
gateway_listeners = gateway.dig("spec", "listeners") || []
unless gateway_listeners.map { |item| item["name"] } == %w[https https-v3-dev https-argocd https-grafana] &&
       gateway_listeners.all? { |item| item["port"] == 443 && item["protocol"] == "HTTPS" && item.dig("tls", "mode") == "Terminate" }
  abort "#{gateway_file}: 443 HTTPS Listener에서 TLS를 종료해야 합니다."
end
gateway_certificate = load_yaml("platform/dev/networking/gateway/certificate.yaml")
gateway_secret_refs = gateway_listeners.flat_map { |item| (item.dig("tls", "certificateRefs") || []).map { |ref| ref["name"] } }
unless gateway_secret_refs.uniq == [gateway_certificate.dig("spec", "secretName")] &&
       gateway_certificate.dig("spec", "issuerRef", "kind") == "ClusterIssuer" &&
       %w[letsencrypt-staging letsencrypt-prod].include?(gateway_certificate.dig("spec", "issuerRef", "name")) &&
       gateway_certificate.dig("spec", "dnsNames").sort == gateway_listeners.map { |item| item["hostname"] }.sort
  abort "Gateway 인증서는 Listener hostname·Secret과 일치하고 Let's Encrypt ClusterIssuer를 사용해야 합니다."
end
gateway_options = load_yaml("platform/dev/networking/gateway/gateway-options.yaml")
gateway_pod_spec = YAML.safe_load(gateway_options.dig("data", "deployment")).dig("spec", "template", "spec")
gateway_service_ports = YAML.safe_load(gateway_options.dig("data", "service").to_s).to_h.dig("spec", "ports") || []
unless gateway_service_ports.include?({ "$patch" => "delete", "port" => 15021 })
  abort "Gateway Service에서 status-port 15021을 제거해 NLB에 15021 Listener가 생기지 않게 해야 합니다."
end
unless gateway.dig("spec", "infrastructure", "parametersRef", "name") == gateway_options.dig("metadata", "name") &&
       gateway_pod_spec.dig("nodeSelector", "lookddak.io/node-pool") == "system" &&
       (gateway_pod_spec["tolerations"] || []).any? { |item| item["key"] == "CriticalAddonsOnly" }
  abort "Gateway Pod는 parametersRef로 System Node 배치와 CriticalAddonsOnly Toleration을 설정해야 합니다."
end
gateway_application = load_yaml("argocd/dev/istio-gateway-application.yaml")
unless gateway_application.dig("metadata", "name") == "lookddak-dev-istio-gateway" &&
       gateway_application.dig("spec", "project") == "lookddak-dev-platform" &&
       gateway_application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "2" &&
       gateway_application.dig("spec", "source", "repoURL") == gitops_repository &&
       gateway_application.dig("spec", "source", "targetRevision") == "main" &&
       gateway_application.dig("spec", "source", "path") == "platform/dev/networking/gateway" &&
       gateway_application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "istio-ingress" }
  abort "argocd/dev/istio-gateway-application.yaml: Gateway Application 설정이 예상과 다릅니다."
end

lbc_chart = load_yaml("platform/dev/networking/aws-load-balancer-controller/Chart.yaml")
lbc_dependency = (lbc_chart["dependencies"] || []).find { |item| item["name"] == "aws-load-balancer-controller" }
unless lbc_dependency &&
       lbc_dependency["version"] == "3.6.2" &&
       lbc_dependency["repository"] == "https://aws.github.io/eks-charts"
  abort "AWS Load Balancer Controller 공식 Chart 3.6.2 의존성을 고정해야 합니다."
end

lbc_values_file = "platform/dev/networking/aws-load-balancer-controller/values.yaml"
lbc_values = load_yaml(lbc_values_file).fetch("aws-load-balancer-controller")
unless lbc_values["clusterName"] == "lookddak-dev" &&
       lbc_values.dig("serviceAccount", "name") == "aws-load-balancer-controller" &&
       lbc_values.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-dev-aws-load-balancer-controller"
  abort "#{lbc_values_file}: lookddak-dev Cluster와 LBC ServiceAccount·IRSA Role 연결이 필요합니다."
end
unless lbc_values.dig("nodeSelector", "lookddak.io/node-pool") == "system" &&
       (lbc_values["tolerations"] || []).any? { |item| item["key"] == "CriticalAddonsOnly" }
  abort "#{lbc_values_file}: LBC는 System Node에 배치하고 CriticalAddonsOnly Toleration이 필요합니다."
end
unless lbc_values["createIngressClassResource"] == false &&
       lbc_values.dig("controllerConfig", "featureGates", "NLBGatewayAPI") == false &&
       lbc_values.dig("controllerConfig", "featureGates", "ALBGatewayAPI") == false
  abort "#{lbc_values_file}: LBC는 Service(NLB) 용도만 사용한다. IngressClass와 Gateway API 기능을 꺼야 합니다."
end

lbc_application_file = "argocd/dev/aws-load-balancer-controller-application.yaml"
lbc_application = load_yaml(lbc_application_file)
unless lbc_application.dig("spec", "project") == "lookddak-dev-platform" &&
       lbc_application.dig("spec", "source", "path") == "platform/dev/networking/aws-load-balancer-controller" &&
       lbc_application.dig("spec", "source", "helm", "releaseName") == "aws-load-balancer-controller" &&
       lbc_application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "kube-system" }
  abort "#{lbc_application_file}: 플랫폼 Project, Chart 경로, Release 이름, kube-system 대상이 예상과 다릅니다."
end
ignored_kinds = (lbc_application.dig("spec", "ignoreDifferences") || []).map { |item| item["kind"] }.sort
unless ignored_kinds == %w[MutatingWebhookConfiguration Secret ValidatingWebhookConfiguration] &&
       (lbc_application.dig("spec", "syncPolicy", "syncOptions") || []).include?("RespectIgnoreDifferences=true")
  abort "#{lbc_application_file}: Webhook 인증서(caBundle·TLS Secret) ignoreDifferences와 RespectIgnoreDifferences가 필요합니다."
end

metrics_server_chart = load_yaml("platform/dev/metrics-server/Chart.yaml")
metrics_server_dependency = (metrics_server_chart["dependencies"] || []).find { |item| item["name"] == "metrics-server" }
unless metrics_server_dependency &&
       metrics_server_dependency["version"] == "3.14.0" &&
       metrics_server_dependency["repository"] == "https://kubernetes-sigs.github.io/metrics-server/"
  abort "Metrics Server 공식 Chart 3.14.0 의존성을 고정해야 합니다."
end

secrets_store_dependencies = {
  "platform/dev/secrets-store-csi/driver/Chart.yaml" => {
    "name" => "secrets-store-csi-driver",
    "version" => "1.6.2",
    "repository" => "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  },
  "platform/dev/secrets-store-csi/provider-aws/Chart.yaml" => {
    "name" => "secrets-store-csi-driver-provider-aws",
    "version" => "3.1.4",
    "repository" => "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  }
}.freeze

secrets_store_dependencies.each do |file, expected|
  dependency = (load_yaml(file)["dependencies"] || []).find { |item| item["name"] == expected["name"] }
  unless dependency && dependency["version"] == expected["version"] && dependency["repository"] == expected["repository"]
    abort "#{file}: 공식 #{expected['name']} Chart #{expected['version']} 의존성을 고정해야 합니다."
  end
end

csi_values_file = "platform/dev/secrets-store-csi/driver/values.yaml"
csi_values = load_yaml(csi_values_file).fetch("secrets-store-csi-driver")
unless csi_values.dig("linux", "nodeSelector", "kubernetes.io/os") == "linux" &&
       (csi_values.dig("linux", "tolerations") || []).include?({ "operator" => "Exists" }) &&
       csi_values.dig("syncSecret", "enabled") == false &&
       csi_values["enableSecretRotation"] == true &&
       csi_values["rotationPollInterval"] == "1h" &&
       (csi_values["tokenRequests"] || []).map { |item| item["audience"] } == %w[sts.amazonaws.com pods.eks.amazonaws.com]
  abort "#{csi_values_file}: 전체 Linux Node 배치, Secret 비복제, 1시간 Rotation과 AWS Token Audience 설정이 필요합니다."
end

provider_values_file = "platform/dev/secrets-store-csi/provider-aws/values.yaml"
provider_values = load_yaml(provider_values_file).fetch("secrets-store-csi-driver-provider-aws")
unless provider_values["awsRegion"] == "ap-northeast-2" &&
       provider_values.dig("secrets-store-csi-driver", "install") == false &&
       provider_values.dig("nodeSelector", "kubernetes.io/os") == "linux" &&
       (provider_values["tolerations"] || []).include?({ "operator" => "Exists" })
  abort "#{provider_values_file}: 서울 Region, Driver 중복 설치 방지와 전체 Linux Node 배치 설정이 필요합니다."
end

secrets_store_applications = {
  "argocd/dev/secrets-store-csi-driver-application.yaml" => {
    "name" => "lookddak-dev-secrets-store-csi-driver",
    "path" => "platform/dev/secrets-store-csi/driver",
    "release" => "secrets-store-csi-driver",
    "wave" => "-1"
  },
  "argocd/dev/secrets-store-csi-provider-aws-application.yaml" => {
    "name" => "lookddak-dev-secrets-store-csi-provider-aws",
    "path" => "platform/dev/secrets-store-csi/provider-aws",
    "release" => "secrets-store-csi-provider-aws",
    "wave" => "0"
  }
}.freeze
secrets_store_automation = {
  "enabled" => true,
  "prune" => true,
  "selfHeal" => true,
  "allowEmpty" => false
}.freeze

secrets_store_applications.each do |file, expected|
  application = load_yaml(file)
  unless application.dig("metadata", "name") == expected["name"] &&
         application.dig("metadata", "namespace") == "argocd" &&
         application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == expected["wave"] &&
         application.dig("spec", "project") == "lookddak-dev-platform" &&
         application.dig("spec", "source", "path") == expected["path"] &&
         application.dig("spec", "source", "helm", "releaseName") == expected["release"] &&
         application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "kube-system" } &&
         application.dig("spec", "syncPolicy", "automated") == secrets_store_automation
    abort "#{file}: Secrets Store 플랫폼 Application 설정이 예상과 다릅니다."
  end
end

karpenter_version = "1.15.1"
{
  "platform/dev/karpenter/crd/Chart.yaml" => "karpenter-crd",
  "platform/dev/karpenter/controller/Chart.yaml" => "karpenter"
}.each do |file, dependency_name|
  chart = load_yaml(file)
  dependency = (chart["dependencies"] || []).find { |item| item["name"] == dependency_name }
  abort "#{file}: #{dependency_name} 의존성이 필요합니다." unless dependency
  abort "#{file}: #{dependency_name} 버전은 #{karpenter_version}이어야 합니다." unless dependency["version"] == karpenter_version
  abort "#{file}: Karpenter 공식 OCI Repository를 사용해야 합니다." unless dependency["repository"] == "oci://public.ecr.aws/karpenter"
end

controller_values_file = "platform/dev/karpenter/controller/values.yaml"
controller_values = load_yaml(controller_values_file).fetch("karpenter")
unless controller_values.dig("settings", "clusterName") == "lookddak-dev" &&
       controller_values.dig("settings", "interruptionQueue") == ""
  abort "#{controller_values_file}: dev Cluster 이름과 비활성화된 Interruption Queue가 필요합니다."
end

unless controller_values.dig("serviceAccount", "name") == "karpenter" &&
       controller_values.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-dev-karpenter-controller"
  abort "#{controller_values_file}: karpenter ServiceAccount와 Controller IRSA Role 연결이 필요합니다."
end

unless controller_values["replicas"] == 2 &&
       controller_values.dig("nodeSelector", "lookddak.io/node-pool") == "system"
  abort "#{controller_values_file}: Controller Replica 2개와 System Node 고정 배치가 필요합니다."
end

expected_resources = {
  "requests" => { "cpu" => "100m", "memory" => "256Mi" },
  "limits" => { "memory" => "512Mi" }
}
unless controller_values.dig("controller", "resources") == expected_resources
  abort "#{controller_values_file}: Controller Resource는 CPU 1, Memory 1Gi로 명시해야 합니다."
end

expected_application_automation = {
  "enabled" => true,
  "prune" => true,
  "selfHeal" => true,
  "allowEmpty" => false
}

karpenter_applications = {
  "argocd/dev/karpenter-crd-application.yaml" => {
    "name" => "lookddak-dev-karpenter-crd",
    "path" => "platform/dev/karpenter/crd",
    "wave" => "-1",
    "skip_crds" => nil,
    "sync_options" => ["ServerSideApply=true", "PruneLast=true"]
  },
  "argocd/dev/karpenter-controller-application.yaml" => {
    "name" => "lookddak-dev-karpenter-controller",
    "path" => "platform/dev/karpenter/controller",
    "wave" => "0",
    "skip_crds" => true,
    "sync_options" => ["PruneLast=true"]
  },
  "argocd/dev/karpenter-nodepool-application.yaml" => {
    "name" => "lookddak-dev-karpenter-nodepool",
    "path" => "platform/dev/karpenter/nodepool",
    "wave" => "1",
    "skip_crds" => nil,
    "sync_options" => ["PruneLast=true"]
  }
}

karpenter_applications.each do |file, expected|
  application = load_yaml(file)
  abort "#{file}: kind가 Application이 아닙니다." unless application["kind"] == "Application"
  abort "#{file}: Application 이름이 예상과 다릅니다." unless application.dig("metadata", "name") == expected["name"]
  abort "#{file}: argocd Namespace에 있어야 합니다." unless application.dig("metadata", "namespace") == "argocd"
  abort "#{file}: 플랫폼 AppProject를 사용해야 합니다." unless application.dig("spec", "project") == "lookddak-dev-platform"
  abort "#{file}: sync-wave가 예상과 다릅니다." unless application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == expected["wave"]
  abort "#{file}: Public GitOps Repository의 main을 추적해야 합니다." unless application.dig("spec", "source", "repoURL") == gitops_repository && application.dig("spec", "source", "targetRevision") == "main"
  abort "#{file}: Helm Chart 경로가 예상과 다릅니다." unless application.dig("spec", "source", "path") == expected["path"]
  abort "#{file}: 배포 대상은 현재 Cluster의 kube-system이어야 합니다." unless application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "kube-system" }
  abort "#{file}: Auto Sync 정책이 예상과 다릅니다." unless application.dig("spec", "syncPolicy", "automated") == expected_application_automation
  abort "#{file}: Sync Option이 예상과 다릅니다." unless application.dig("spec", "syncPolicy", "syncOptions") == expected["sync_options"]

  actual_skip_crds = application.dig("spec", "source", "helm", "skipCrds")
  abort "#{file}: Controller Application만 내장 CRD를 제외해야 합니다." unless actual_skip_crds == expected["skip_crds"]
end

nodepool_application = load_yaml("argocd/dev/karpenter-nodepool-application.yaml")
unless nodepool_application.dig("spec", "source", "directory", "include") == "{ec2-nodeclass.yaml,nodepool.yaml,redis-nodepool.yaml}"
  abort "NodePool Application은 승인된 EC2NodeClass·NodePool 파일만 배포해야 합니다."
end

nodepool = load_yaml("platform/dev/karpenter/nodepool/nodepool.yaml")
nodeclass = load_yaml("platform/dev/karpenter/nodepool/ec2-nodeclass.yaml")
abort "NodePool·EC2NodeClass는 general-purpose 이름을 사용해야 합니다." unless [nodepool, nodeclass].all? { |item| item.dig("metadata", "name") == "general-purpose" }
abort "NodePool·EC2NodeClass는 Namespace를 지정하지 않는 Cluster 리소스입니다." if [nodepool, nodeclass].any? { |item| item.dig("metadata", "namespace") }
abort "동적 NodePool에는 고정 replicas를 지정하지 않습니다." if nodepool.fetch("spec").key?("replicas")

node_template = nodepool.dig("spec", "template", "spec")
unless node_template["nodeClassRef"] == { "group" => "karpenter.k8s.aws", "kind" => "EC2NodeClass", "name" => "general-purpose" }
  abort "NodePool은 general-purpose EC2NodeClass를 참조해야 합니다."
end
unless nodepool.dig("spec", "template", "metadata", "labels", "lookddak.io/node-pool") == "general-purpose"
  abort "Application Node 식별 Label이 필요합니다."
end
expected_requirements = {
  "kubernetes.io/os" => ["In", %w[linux]],
  "kubernetes.io/arch" => ["In", %w[arm64]],
  "karpenter.sh/capacity-type" => ["In", %w[on-demand]],
  "karpenter.k8s.aws/instance-category" => ["In", %w[c m r]],
  "karpenter.k8s.aws/instance-generation" => ["Gt", %w[4]],
  "karpenter.k8s.aws/instance-cpu" => ["In", %w[2 4 8]],
  "topology.kubernetes.io/zone" => ["In", %w[ap-northeast-2a ap-northeast-2c]]
}
requirements = node_template.fetch("requirements")
actual_requirements = requirements.to_h { |item| [item.fetch("key"), [item.fetch("operator"), item.fetch("values")]] }
unless actual_requirements == expected_requirements && requirements.length == expected_requirements.length
  abort "NodePool 인스턴스 조건이 승인된 Linux·ARM64·On-Demand·C/M/R·세대·CPU·AZ 범위와 다릅니다."
end
unless node_template["startupTaints"] == [{ "key" => "node.cilium.io/agent-not-ready", "value" => "true", "effect" => "NoExecute" }] && (node_template["taints"] || []).empty?
  abort "고정 Taint 없이 Cilium Startup Taint를 선언해야 합니다."
end
unless nodepool.dig("spec", "limits") == { "cpu" => "32", "memory" => "64Gi" }
  abort "Dev 초기 공급 상한은 CPU 32·Memory 64Gi입니다. 부하 테스트 후 정책과 검증을 함께 갱신하세요."
end
unless nodepool.dig("spec", "disruption") == { "consolidationPolicy" => "WhenEmptyOrUnderutilized", "consolidateAfter" => "5m", "budgets" => [{ "nodes" => "1" }] } && node_template["expireAfter"] == "Never"
  abort "회수 정책은 WhenEmptyOrUnderutilized·5분 대기·동시 1대이며 시간 만료는 비활성화합니다."
end
# Redis 전용 NodePool (k8s-design/11 §4-6): Label·Taint로 Redis만 배치, c7g.medium 고정, 통합으로 이동하지 않음, 상한 3대
redis_nodepool = load_yaml("platform/dev/karpenter/nodepool/redis-nodepool.yaml")
redis_node_template = redis_nodepool.dig("spec", "template", "spec")
redis_requirements = redis_node_template.fetch("requirements").to_h { |item| [item.fetch("key"), [item.fetch("operator"), item.fetch("values")]] }
unless redis_nodepool["kind"] == "NodePool" && redis_nodepool.dig("metadata", "name") == "redis" && !redis_nodepool.dig("metadata", "namespace") && !redis_nodepool.fetch("spec").key?("replicas") &&
       redis_nodepool.dig("spec", "template", "metadata", "labels", "lookddak.io/node-pool") == "redis" &&
       redis_node_template["nodeClassRef"] == { "group" => "karpenter.k8s.aws", "kind" => "EC2NodeClass", "name" => "general-purpose" } &&
       redis_node_template["taints"] == [{ "key" => "lookddak.io/dedicated", "value" => "redis", "effect" => "NoSchedule" }] &&
       redis_node_template["startupTaints"] == [{ "key" => "node.cilium.io/agent-not-ready", "value" => "true", "effect" => "NoExecute" }] &&
       redis_node_template["expireAfter"] == "Never" &&
       redis_requirements == {
         "kubernetes.io/os" => ["In", %w[linux]],
         "kubernetes.io/arch" => ["In", %w[arm64]],
         "karpenter.sh/capacity-type" => ["In", %w[on-demand]],
         "node.kubernetes.io/instance-type" => ["In", %w[c7g.medium]],
         "topology.kubernetes.io/zone" => ["In", %w[ap-northeast-2a ap-northeast-2c]]
       } &&
       redis_nodepool.dig("spec", "limits") == { "cpu" => "3", "memory" => "6Gi" } &&
       redis_nodepool.dig("spec", "disruption") == { "consolidationPolicy" => "WhenEmpty", "consolidateAfter" => "5m", "budgets" => [{ "nodes" => "1" }] }
  abort "platform/dev/karpenter/nodepool/redis-nodepool.yaml: Redis NodePool은 redis Label·Taint, c7g.medium·arm64·On-Demand·2a/2c, WhenEmpty, 상한 3대여야 합니다."
end
redis_cluster_scheduling = load_yaml("platform/dev/redis/cluster/redis-cluster.yaml").fetch("spec").values_at("redisLeader", "redisFollower")
unless redis_cluster_scheduling.all? { |role| role["nodeSelector"] == { "lookddak.io/node-pool" => "redis" } && role["tolerations"] == [{ "key" => "lookddak.io/dedicated", "operator" => "Equal", "value" => "redis", "effect" => "NoSchedule" }] } &&
       redis_cluster_scheduling.all? { |role| (role["topologySpreadConstraints"] || []).any? { |rule| rule["topologyKey"] == "topology.kubernetes.io/zone" && rule["maxSkew"] == 1 && rule["whenUnsatisfiable"] == "DoNotSchedule" } }
  abort "platform/dev/redis/cluster/redis-cluster.yaml: leader·follower는 Redis NodePool Label·Taint와 짝이 맞고 AZ 분산(zone maxSkew 1, DoNotSchedule)이 필요합니다."
end

unless nodeclass.dig("spec", "instanceProfile") == "lookddak-dev-karpenter-node" && !nodeclass.fetch("spec").key?("role")
  abort "Terraform에서 생성한 Karpenter Node Instance Profile을 사용해야 합니다."
end
unless nodeclass.dig("spec", "amiSelectorTerms")&.all? { |term| term["alias"].to_s.match?(/\Aal2023@v\d{8}\z/) }
  abort "EKS AL2023 AMI 날짜 버전을 고정해야 합니다."
end
unless nodeclass.dig("spec", "subnetSelectorTerms") == [{ "tags" => { "karpenter.sh/discovery" => "lookddak-dev", "Tier" => "private-node" } }] && nodeclass.dig("spec", "associatePublicIPAddress") == false
  abort "Node 전용 Private Subnet만 선택하고 Public IP는 비활성화해야 합니다."
end
unless nodeclass.dig("spec", "securityGroupSelectorTerms") == [{ "id" => "sg-04d109eb4f8eae342" }]
  abort "조회로 확인한 기존 EKS Cluster SG를 사용해야 합니다."
end
unless nodeclass.dig("spec", "blockDeviceMappings") == [{ "deviceName" => "/dev/xvda", "ebs" => { "volumeType" => "gp3", "volumeSize" => "30Gi", "encrypted" => true, "deleteOnTermination" => true } }]
  abort "Root Volume은 암호화 gp3 30Gi, 종료 시 삭제 정책이어야 합니다."
end

dev_namespace_files = Dir["argocd/dev/namespace-*.yaml"].sort
actual_dev_namespaces = dev_namespace_files.map do |file|
  manifest = load_yaml(file)
  abort "#{file}: kind가 Namespace가 아닙니다." unless manifest["kind"] == "Namespace"
  abort "#{file}: Namespace 자동 삭제 방지를 위해 Prune=false가 필요합니다." unless manifest.dig("metadata", "annotations", "argocd.argoproj.io/sync-options") == "Prune=false"
  abort "#{file}: ApplicationSet보다 먼저 적용할 sync-wave -1이 필요합니다." unless manifest.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-1"
  manifest.dig("metadata", "name")
end.sort

platform_namespaces = %w[istio-system istio-ingress monitoring].freeze
# 데이터 계층 Namespace: 도메인 라벨 없이 Ambient만 등록 (외부 Gateway Route 연결 불가)
data_namespaces = %w[lookddak-redis].freeze
unless actual_dev_namespaces == (dev_namespaces + platform_namespaces + data_namespaces).sort
  abort "dev Namespace 구성이 설계와 다릅니다. 예상=#{(dev_namespaces + platform_namespaces + data_namespaces).sort}, 실제=#{actual_dev_namespaces}"
end

# 도메인 Namespace만 Istio Ambient에 등록한다 (플랫폼 Namespace는 메시 밖)
dev_namespace_files.each do |file|
  manifest = load_yaml(file)
  labels = manifest.dig("metadata", "labels") || {}
  if data_namespaces.include?(manifest.dig("metadata", "name"))
    abort "#{file}: 데이터 Namespace는 도메인 라벨 없이 tier: data와 Ambient 등록이 필요합니다." unless !labels.key?("lookddak.com/domain") && labels["lookddak.com/tier"] == "data" && labels["istio.io/dataplane-mode"] == "ambient"
  elsif labels.key?("lookddak.com/domain")
    abort "#{file}: 도메인 Namespace는 istio.io/dataplane-mode: ambient가 필요합니다." unless labels["istio.io/dataplane-mode"] == "ambient"
  elsif labels.key?("istio.io/dataplane-mode")
    abort "#{file}: 플랫폼 Namespace는 Ambient에 등록하지 않습니다."
  end
end

# 네트워크 정책: 도메인 기본 차단 + Ambient 필수 허용, 도메인 Namespace마다 내부 허용
baseline = load_yaml("platform/dev/networking/policies/domain-baseline.yaml")
baseline_ingress_cidrs = (baseline.dig("spec", "ingress") || []).flat_map { |rule| rule["fromCIDR"] || [] }
unless baseline["kind"] == "CiliumClusterwideNetworkPolicy" &&
       baseline.dig("spec", "endpointSelector", "matchExpressions") == [{ "key" => "k8s:io.cilium.k8s.namespace.labels.lookddak.com/domain", "operator" => "Exists" }] &&
       baseline_ingress_cidrs == ["169.254.7.127/32"] &&
       baseline.dig("spec", "egress").any? { |rule| (rule["toPorts"] || []).any? { |port| port.dig("rules", "dns") } }
  abort "도메인 baseline 정책은 도메인 Namespace 선택, Ambient probe 허용, DNS 허용이 필요합니다."
end
same_namespace_targets = YAML.load_stream(File.read("platform/dev/networking/policies/domain-same-namespace.yaml")).compact.map do |policy|
  namespace = policy.dig("spec", "endpointSelector", "matchLabels", "k8s:io.kubernetes.pod.namespace")
  peers = (policy.dig("spec", "ingress") || []) + (policy.dig("spec", "egress") || [])
  unless peers.length == 2 && peers.all? { |rule| ((rule["fromEndpoints"] || rule["toEndpoints"]) || []) == [{ "matchLabels" => { "k8s:io.kubernetes.pod.namespace" => namespace } }] }
    abort "#{policy.dig('metadata', 'name')}: 같은 Namespace끼리만 허용해야 합니다."
  end
  namespace
end.sort
unless same_namespace_targets == dev_namespaces.sort
  abort "도메인 Namespace마다 같은 Namespace 허용 정책이 필요합니다. 예상=#{dev_namespaces.sort}, 실제=#{same_namespace_targets}"
end
policy_application = load_yaml("argocd/dev/network-policies-application.yaml")
unless policy_application.dig("spec", "project") == "lookddak-dev-platform" &&
       policy_application.dig("spec", "source", "path") == "platform/dev/networking/policies" &&
       policy_application.dig("spec", "source", "targetRevision") == "main" &&
       policy_application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "kube-system" }
  abort "argocd/dev/network-policies-application.yaml: 네트워크 정책 Application 설정이 예상과 다릅니다."
end

# 메시 보안: 메시 전체 mTLS STRICT, 도메인 NS마다 Istio 인가 기본값
peer_authentication = load_yaml("platform/dev/networking/mesh-security/peer-authentication.yaml")
unless peer_authentication["kind"] == "PeerAuthentication" &&
       peer_authentication.dig("metadata", "namespace") == "istio-system" &&
       peer_authentication.dig("metadata", "name") == "default" &&
       peer_authentication.dig("spec", "mtls", "mode") == "STRICT" &&
       !peer_authentication.dig("spec", "selector")
  abort "메시 전체 PeerAuthentication은 istio-system/default STRICT여야 합니다."
end
mesh_application = load_yaml("argocd/dev/mesh-security-application.yaml")
unless mesh_application.dig("spec", "project") == "lookddak-dev-platform" &&
       mesh_application.dig("spec", "source", "path") == "platform/dev/networking/mesh-security" &&
       mesh_application.dig("spec", "source", "targetRevision") == "main" &&
       mesh_application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "istio-system" }
  abort "argocd/dev/mesh-security-application.yaml: 메시 보안 Application 설정이 예상과 다릅니다."
end
Dir["environments/dev/domains/*/domain.yaml"].sort.each do |file|
  abort "#{file}: dev 도메인은 Istio 인가 기본값(authorizationPolicy.enabled)이 필요합니다." unless load_yaml(file).dig("authorizationPolicy", "enabled") == true
end

# 내부 API 라우팅: waypoint 사용 Service, 대상 Namespace ReferenceGrant
internal_service = load_yaml("platform/dev/networking/internal-api/api-service.yaml")
abort "내부 API Service는 waypoint를 사용하고 Pod를 선택하지 않아야 합니다." unless internal_service.dig("metadata", "labels", "istio.io/use-waypoint") == "waypoint" && !internal_service.dig("spec", "selector")
internal_route = load_yaml("platform/dev/networking/internal-api/api-httproute.yaml")
backend_namespaces = internal_route.dig("spec", "rules").flat_map { |rule| rule["backendRefs"].map { |ref| ref["namespace"] } }.uniq.sort
grant_namespaces = YAML.load_stream(File.read("platform/dev/networking/internal-api/reference-grants.yaml")).compact.map { |grant| grant.dig("metadata", "namespace") }.sort
abort "내부 API backend Namespace마다 ReferenceGrant가 필요합니다. backend=#{backend_namespaces}, grant=#{grant_namespaces}" unless backend_namespaces == grant_namespaces
internal_authz = load_yaml("platform/dev/networking/internal-api/authorization-policy.yaml")
internal_authz_targets = internal_authz.dig("spec", "targetRefs")
internal_authz_principals = Array(internal_authz.dig("spec", "rules")).flat_map { |rule| Array(rule["from"]).flat_map { |from| Array(from.dig("source", "principals")) } }
unless internal_authz["kind"] == "AuthorizationPolicy" &&
       internal_authz.dig("metadata", "namespace") == "lookddak-web" &&
       internal_authz.dig("spec", "action") == "ALLOW" &&
       internal_authz_targets == [{ "group" => "", "kind" => "Service", "name" => "api" }] &&
       internal_authz_principals == ["cluster.local/ns/lookddak-web/sa/web-bff"] &&
       !internal_authz.dig("spec", "selector")
  abort "platform/dev/networking/internal-api/authorization-policy.yaml: 내부 API 인가는 Service api 대상, web-bff 신원만 허용해야 합니다."
end
internal_application = load_yaml("argocd/dev/internal-api-application.yaml")
unless internal_application.dig("spec", "project") == "lookddak-dev" &&
       internal_application.dig("spec", "source", "path") == "platform/dev/networking/internal-api" &&
       internal_application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-web" }
  abort "argocd/dev/internal-api-application.yaml: 내부 API Application 설정이 예상과 다릅니다."
end

# AI 서킷 브레이커 waypoint: body-image-validator 앞단, chat-ai egress(Runware·OpenAI)
body_image_validator = load_yaml("environments/dev/domains/identity/workloads/body-image-validator.yaml")
unless body_image_validator.dig("service", "labels", "istio.io/use-waypoint") == "waypoint" &&
       body_image_validator.dig("trafficPolicy", "enabled") == true &&
       body_image_validator.dig("trafficPolicy", "outlierDetection", "maxEjectionPercent") == 100
  abort "body-image-validator: identity waypoint 사용과 서킷 브레이커(trafficPolicy, maxEjectionPercent 100)가 필요합니다."
end
identity_waypoint = YAML.load_stream(File.read("platform/dev/networking/ai-waypoint/identity-waypoint.yaml")).compact.find { |item| item["kind"] == "Gateway" }
chat_egress_waypoint = YAML.load_stream(File.read("platform/dev/networking/ai-waypoint/chat-egress-waypoint.yaml")).compact.find { |item| item["kind"] == "Gateway" }
unless identity_waypoint && identity_waypoint.dig("metadata", "namespace") == "lookddak-identity" && identity_waypoint.dig("metadata", "name") == "waypoint" && identity_waypoint.dig("spec", "gatewayClassName") == "istio-waypoint" &&
       chat_egress_waypoint && chat_egress_waypoint.dig("metadata", "namespace") == "lookddak-chat" && chat_egress_waypoint.dig("metadata", "name") == "egress-waypoint" && chat_egress_waypoint.dig("spec", "gatewayClassName") == "istio-waypoint"
  abort "platform/dev/networking/ai-waypoint: identity waypoint·chat egress-waypoint Gateway 설정이 예상과 다릅니다."
end
chat_egress_resources = YAML.load_stream(File.read("platform/dev/networking/ai-waypoint/chat-egress-services.yaml")).compact
chat_egress_entries = chat_egress_resources.select { |item| item["kind"] == "ServiceEntry" }
chat_egress_rules = chat_egress_resources.select { |item| item["kind"] == "DestinationRule" }
unless chat_egress_entries.map { |item| item.dig("spec", "hosts") }.flatten.sort == %w[api.openai.com api.runware.ai] &&
       chat_egress_entries.all? { |item| item.dig("metadata", "namespace") == "lookddak-chat" && item.dig("spec", "exportTo") == ["."] && item.dig("metadata", "labels", "istio.io/use-waypoint") == "egress-waypoint" && item.dig("spec", "location") == "MESH_EXTERNAL" } &&
       chat_egress_rules.map { |item| item.dig("spec", "host") }.sort == %w[api.openai.com api.runware.ai] &&
       chat_egress_rules.all? { |item| item.dig("spec", "exportTo") == ["."] && item.dig("spec", "trafficPolicy", "outlierDetection", "maxEjectionPercent") == 100 && item.dig("spec", "trafficPolicy", "portLevelSettings", 0, "tls", "mode") == "SIMPLE" && item.dig("spec", "trafficPolicy", "portLevelSettings", 0, "outlierDetection", "maxEjectionPercent") == 100 }
  abort "platform/dev/networking/ai-waypoint/chat-egress-services.yaml: Runware·OpenAI ServiceEntry·DestinationRule은 lookddak-chat 전용, egress-waypoint, TLS 연결, 서킷 브레이커가 필요합니다."
end
ai_waypoint_application = load_yaml("argocd/dev/ai-waypoint-application.yaml")
unless ai_waypoint_application.dig("spec", "project") == "lookddak-dev" &&
       ai_waypoint_application.dig("spec", "source", "path") == "platform/dev/networking/ai-waypoint"
  abort "argocd/dev/ai-waypoint-application.yaml: AI waypoint Application 설정이 예상과 다릅니다."
end

# Redis Cluster (platform/dev/redis): CRD 분리, 영속화 없음, 외부 노출 금지, chat-api만 허용
redis_operator_dependency = (load_yaml("platform/dev/redis/operator/Chart.yaml")["dependencies"] || []).find { |item| item["name"] == "redis-operator" }
unless redis_operator_dependency && redis_operator_dependency["version"] == "0.27.0" && redis_operator_dependency["repository"] == "https://ot-container-kit.github.io/helm-charts"
  abort "platform/dev/redis/operator/Chart.yaml: OT-CONTAINER-KIT redis-operator 0.27.0 의존성을 고정해야 합니다."
end
redis_operator_values = load_yaml("platform/dev/redis/operator/values.yaml").fetch("redis-operator")
unless redis_operator_values.dig("redisOperator", "watchNamespace") == "lookddak-redis" && redis_operator_values.dig("rbac", "scope") == "namespace"
  abort "platform/dev/redis/operator/values.yaml: Operator 감시·RBAC 범위는 lookddak-redis Namespace로 한정해야 합니다."
end
unless redis_operator_values["featureGates"] == { "GenerateConfigInInitContainer" => true }
  abort "platform/dev/redis/operator/values.yaml: Redis가 headless FQDN을 알리도록 featureGates.GenerateConfigInInitContainer: true가 필요합니다 (기본은 짧은 Pod 이름 → 다른 Namespace 클라이언트 접속 실패)."
end
redis_crd_names = YAML.load_stream(File.read("platform/dev/redis/crds/crds.yaml")).compact.map { |crd| crd.dig("metadata", "name") }.sort
abort "platform/dev/redis/crds/crds.yaml: redis-operator CRD 4개가 필요합니다. 실제=#{redis_crd_names}" unless redis_crd_names == %w[redis.redis.redis.opstreelabs.in redisclusters.redis.redis.opstreelabs.in redisreplications.redis.redis.opstreelabs.in redissentinels.redis.redis.opstreelabs.in]
redis_applications = {
  "argocd/dev/redis-crds-application.yaml" => { "name" => "lookddak-dev-redis-crds", "path" => "platform/dev/redis/crds", "wave" => "-1", "prune" => false },
  "argocd/dev/redis-operator-application.yaml" => { "name" => "lookddak-dev-redis-operator", "path" => "platform/dev/redis/operator", "wave" => "0", "prune" => true },
  "argocd/dev/redis-cluster-application.yaml" => { "name" => "lookddak-dev-redis-cluster", "path" => "platform/dev/redis/cluster", "wave" => "1", "prune" => false }
}.freeze
redis_applications.each do |file, expected|
  application = load_yaml(file)
  unless application.dig("metadata", "name") == expected["name"] &&
         application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == expected["wave"] &&
         application.dig("spec", "project") == "lookddak-dev-platform" &&
         application.dig("spec", "source", "repoURL") == gitops_repository &&
         application.dig("spec", "source", "targetRevision") == "main" &&
         application.dig("spec", "source", "path") == expected["path"] &&
         application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-redis" } &&
         application.dig("spec", "syncPolicy", "automated", "prune") == expected["prune"]
    abort "#{file}: Redis Application 설정이 예상과 다릅니다 (CRD·RedisCluster는 prune 끔)."
  end
end
abort "argocd/dev/redis-operator-application.yaml: CRD는 별도 Application이 관리하므로 skipCrds: true가 필요합니다." unless load_yaml("argocd/dev/redis-operator-application.yaml").dig("spec", "source", "helm", "skipCrds") == true
redis_cluster = load_yaml("platform/dev/redis/cluster/redis-cluster.yaml")
unless redis_cluster["kind"] == "RedisCluster" && redis_cluster.dig("spec", "persistenceEnabled") == false && !redis_cluster.dig("spec", "storage") &&
       redis_cluster.dig("spec", "kubernetesConfig", "image").to_s.match?(/:v\d+\.\d+\.\d+\z/)
  abort "platform/dev/redis/cluster/redis-cluster.yaml: 영속화·PV 없음, Redis 이미지 버전 태그 고정이 필요합니다."
end
# RedisCluster CR을 보관한 CRD(v1beta2) 스키마로 검사: 필수 필드 누락·알 수 없는 필드
redis_cluster_crd = YAML.load_stream(File.read("platform/dev/redis/crds/crds.yaml")).compact.find { |crd| crd.dig("metadata", "name") == "redisclusters.redis.redis.opstreelabs.in" }
redis_cluster_schema = redis_cluster_crd.dig("spec", "versions").find { |version| version["name"] == "v1beta2" }.dig("schema", "openAPIV3Schema", "properties", "spec")
redis_schema_errors = []
check_redis_schema = lambda do |schema, value, path|
  next unless value.is_a?(Hash) && schema.is_a?(Hash)
  (schema["required"] || []).each { |key| redis_schema_errors << "#{path}.#{key} 필수" unless value.key?(key) }
  properties = schema["properties"] || {}
  value.each do |key, child|
    if properties.key?(key)
      check_redis_schema.call(properties[key], child, "#{path}.#{key}")
    elsif !properties.empty? && !schema["x-kubernetes-preserve-unknown-fields"] && !schema.key?("additionalProperties")
      redis_schema_errors << "#{path}.#{key} 알 수 없는 필드"
    end
  end
end
check_redis_schema.call(redis_cluster_schema, redis_cluster.fetch("spec"), "spec")
abort "platform/dev/redis/cluster/redis-cluster.yaml: RedisCluster CRD 스키마와 맞지 않습니다: #{redis_schema_errors}" unless redis_schema_errors.empty?
redis_external_routes = Dir["{platform,environments}/**/*.yaml"].reject { |file| file.match?(%r{/templates/}) }.select do |file|
  YAML.load_stream(File.read(file)).compact.any? { |doc| doc.is_a?(Hash) && %w[HTTPRoute GRPCRoute TCPRoute TLSRoute].include?(doc["kind"]) && doc.dig("metadata", "namespace") == "lookddak-redis" }
end
abort "lookddak-redis에는 Route를 만들지 않습니다(외부 노출 금지): #{redis_external_routes}" unless redis_external_routes.empty?
redis_policies = YAML.load_stream(File.read("platform/dev/networking/policies/redis-network-policy.yaml")).compact
redis_ingress_clients = redis_policies.find { |policy| policy.dig("metadata", "name") == "lookddak-redis" }&.dig("spec", "ingress").to_a.flat_map { |rule| rule["fromEndpoints"].to_a }.map { |endpoint| endpoint["matchLabels"] }
unless redis_ingress_clients.sort_by(&:to_s) == [{ "k8s:io.kubernetes.pod.namespace" => "lookddak-redis" }, { "k8s:io.kubernetes.pod.namespace" => "lookddak-chat", "k8s:app.kubernetes.io/name" => "chat-api" }, { "k8s:io.kubernetes.pod.namespace" => "monitoring", "k8s:app.kubernetes.io/instance" => "alloy-cluster" }, { "k8s:io.kubernetes.pod.namespace" => "monitoring", "k8s:app.kubernetes.io/name" => "grafana" }].sort_by(&:to_s)
  abort "platform/dev/networking/policies/redis-network-policy.yaml: Redis ingress는 같은 Namespace, chat-api, 메트릭 수집(monitoring/alloy-cluster), Grafana 읽기 전용 조회만 허용해야 합니다. 실제=#{redis_ingress_clients}"
end
redis_authz_principals = YAML.load_stream(File.read("platform/dev/redis/cluster/authorization-policy.yaml")).compact.flat_map { |policy| policy.dig("spec", "rules").to_a.flat_map { |rule| rule["from"].to_a.flat_map { |from| from.dig("source", "principals").to_a } } }
abort "platform/dev/redis/cluster/authorization-policy.yaml: 외부 신원은 chat-api, 메트릭 수집(alloy-cluster), Grafana만 허용합니다. 실제=#{redis_authz_principals}" unless redis_authz_principals.sort == ["cluster.local/ns/lookddak-chat/sa/chat-api", "cluster.local/ns/monitoring/sa/alloy-cluster", "cluster.local/ns/monitoring/sa/grafana"].sort
redis_grafana_policy = YAML.load_stream(File.read("platform/dev/redis/cluster/authorization-policy.yaml")).compact.find { |policy| policy.dig("metadata", "name") == "allow-grafana-readonly" }
unless redis_grafana_policy && redis_grafana_policy.dig("spec", "rules", 0, "to") == [{ "operation" => { "ports" => ["6379"] } }]
  abort "platform/dev/redis/cluster/authorization-policy.yaml: Grafana는 6379만 허용해야 합니다."
end
redis_acl_lines = load_yaml("platform/dev/redis/cluster/redis-cluster-config.yaml").dig("data", "redis-additional.conf").to_s.lines.map(&:strip).select { |line| line.start_with?("user ", "__") }
unless redis_acl_lines.size == 1 && redis_acl_lines[0].match?(/\Auser be-readonly on #[0-9a-f]{64} ~\* resetchannels -@all \+@read \+@connection .*-@dangerous \+info\z/)
  abort "platform/dev/redis/cluster/redis-cluster-config.yaml: Redis ACL은 be-readonly 읽기 전용 사용자 하나(비밀번호 SHA-256 해시, 쓰기·@dangerous 차단)만 둡니다. terraform output dev_v3_redis_readonly_acl_rule 값으로 채우세요."
end
redis_alloy_policy = YAML.load_stream(File.read("platform/dev/redis/cluster/authorization-policy.yaml")).compact.find { |policy| policy.dig("metadata", "name") == "allow-alloy-cluster-metrics" }
unless redis_alloy_policy && redis_alloy_policy.dig("spec", "rules", 0, "to") == [{ "operation" => { "ports" => ["6379"] } }]
  abort "platform/dev/redis/cluster/authorization-policy.yaml: alloy-cluster는 6379만 허용해야 합니다."
end

# 워크로드별 egress 정책: 파일 이름 = 워크로드, 해당 워크로드 Pod만 선택, 목적지는 FQDN만
dev_workload_namespaces = Dir["environments/dev/domains/*/workloads/*.yaml"].to_h do |file|
  [File.basename(file, ".yaml"), "lookddak-#{file.split('/')[3]}"]
end
Dir["platform/dev/networking/policies/*-egress.yaml"].sort.each do |file|
  workload = File.basename(file, "-egress.yaml")
  policy = load_yaml(file)
  expected_selector = { "k8s:io.kubernetes.pod.namespace" => dev_workload_namespaces[workload], "k8s:app.kubernetes.io/name" => workload }
  unless dev_workload_namespaces.key?(workload) &&
         policy["kind"] == "CiliumClusterwideNetworkPolicy" &&
         policy.dig("metadata", "name") == "lookddak-dev-#{workload}-egress" &&
         policy.dig("spec", "endpointSelector", "matchLabels") == expected_selector &&
         !policy.dig("spec", "endpointSelector", "matchExpressions") &&
         (policy.dig("spec", "egress") || []).all? { |rule| rule["toFQDNs"] && rule.keys.sort == %w[toFQDNs toPorts] }
    abort "#{file}: 워크로드 egress 정책은 lookddak-dev-<워크로드>-egress 이름으로 해당 워크로드 Pod만 선택하고 FQDN만 허용해야 합니다."
  end
end

dev_domain_set = load_yaml("argocd/dev/domain-applicationset.yaml")
dev_workload_set = load_yaml("argocd/dev/workload-applicationset.yaml")

expected_domain_value_files = [
  "$values/{{ .path.path }}/{{ .path.filename }}"
]
expected_workload_value_files = [
  "$values/environments/dev/images.yaml",
  "$values/{{ .path.path }}/{{ .path.filename }}"
]

actual_domain_value_files = dev_domain_set.dig("spec", "template", "spec", "sources", 0, "helm", "valueFiles")
actual_workload_value_files = dev_workload_set.dig("spec", "template", "spec", "sources", 0, "helm", "valueFiles")

unless actual_domain_value_files == expected_domain_value_files
  abort "dev Domain ApplicationSet은 Git generator가 찾은 domain.yaml 파일을 Helm values로 사용해야 합니다."
end

unless actual_workload_value_files == expected_workload_value_files
  abort "dev Workload ApplicationSet은 images.yaml과 Git generator가 찾은 workload YAML 파일을 Helm values로 사용해야 합니다."
end

[dev_domain_set, dev_workload_set].each do |application_set|
  unless application_set.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "0"
    abort "#{application_set.dig('metadata', 'name')}: Namespace 이후에 적용할 sync-wave 0이 필요합니다."
  end
end

unless dev_domain_set.dig("spec", "template", "spec", "project") == "lookddak-dev" &&
       dev_workload_set.dig("spec", "template", "spec", "project") == "lookddak-dev"
  abort "dev ApplicationSet은 lookddak-dev AppProject를 사용해야 합니다."
end

workload_sync_policy = dev_workload_set.dig("spec", "template", "spec", "syncPolicy") || {}
if workload_sync_policy.key?("automated")
  abort "dev Workload Auto Sync는 워크로드별 templatePatch로만 설정해야 합니다."
end
unless workload_sync_policy["syncOptions"] == ["PruneLast=true"]
  abort "dev Workload Application에는 PruneLast=true가 필요합니다."
end

workload_template_patch = dev_workload_set.dig("spec", "templatePatch").to_s
required_patch_fragments = [
  "{{- if .gitops.autoSync }}",
  "automated:",
  "enabled: true",
  "prune: true",
  "selfHeal: true",
  "allowEmpty: false"
]
unless required_patch_fragments.all? { |fragment| workload_template_patch.include?(fragment) }
  abort "dev Workload ApplicationSet에 워크로드별 Auto Sync templatePatch가 필요합니다."
end

# Chat 도메인: API와 AI 각 2개 Pod를 한 PR에서 함께 활성화한다.
chat_api_file = "environments/dev/domains/chat/workloads/chat-api.yaml"
chat_api = load_yaml(chat_api_file)
unless chat_api.dig("gitops", "autoSync") == true &&
       chat_api.dig("workload", "runtimeRole") == "chat-api" &&
       chat_api["replicaCount"] == 2 &&
       chat_api.dig("container", "port") == 8080 &&
       chat_api.dig("deployment", "terminationGracePeriodSeconds") == 330 &&
       chat_api.dig("service", "enabled") == true &&
       chat_api.dig("service", "port") == 80 &&
       chat_api.dig("pdb", "maxUnavailable") == 1 &&
       chat_api.dig("secrets", "secretProviderClassName") == "chat-api" &&
       chat_api.dig("container", "env")&.include?({ "name" => "SPRING_PROFILES_ACTIVE", "value" => "prod,chat-api" }) &&
       chat_api.dig("container", "env")&.include?({ "name" => "REDIS_CLUSTER_NODES", "value" => "redis-cache-master.lookddak-redis.svc.cluster.local:6379" }) &&
       chat_api.dig("container", "env")&.include?({ "name" => "CHAT_REDIS_ENABLED", "value" => "true" }) &&
       chat_api.dig("container", "env")&.include?({ "name" => "MANAGEMENT_HEALTH_REDIS_ENABLED", "value" => "false" }) &&
       chat_api.dig("container", "env").none? { |entry| %w[REDIS_PASSWORD REDIS_HOST REDIS_PORT].include?(entry["name"]) } &&
       File.file?("platform/dev/networking/policies/chat-api-egress.yaml")
  abort "#{chat_api_file}: Chat API의 Auto Sync·Replica·SSE 종료·Redis Cluster 연결·Secret 설정이 필요합니다."
end

%w[
  environments/dev/domains/commerce/workloads/commerce-api.yaml
  environments/dev/domains/fitting/workloads/fitting-api.yaml
  environments/dev/domains/fitting/workloads/fitting-worker.yaml
  environments/dev/domains/identity/workloads/identity-api.yaml
].each do |file|
  env = load_yaml(file).dig("container", "env") || []
  unless env.include?({ "name" => "SPRING_PROFILES_ACTIVE", "value" => "prod" }) &&
         env.none? { |entry| entry["name"].to_s.start_with?("REDIS_") || entry["name"] == "CHAT_REDIS_ENABLED" }
    abort "#{file}: Redis는 chat-api만 사용합니다. SPRING_PROFILES_ACTIVE=prod를 유지하고 Redis env를 넣지 마세요."
  end
end

chat_api_parameter_names = chat_api.dig("secrets", "parameters", "objects").to_s.scan(%r{objectName: (/[A-Za-z0-9_./-]+)}).flatten
expected_chat_api_parameters = %w[
  /lookddak/dev/v3/mysql/jdbc-url
  /lookddak/dev/v3/mysql/app/username
  /lookddak/dev/v3/mysql/app/password
  /lookddak/dev/spring/jwt-secret
  /lookddak/dev/internal/ai-api-key
]
unless chat_api_parameter_names == expected_chat_api_parameters
  abort "#{chat_api_file}: Chat API Parameter 목록은 실제 V3 IRSA 정책과 같아야 합니다."
end

chat_ai_file = "environments/dev/domains/chat/workloads/chat-ai.yaml"
chat_ai = load_yaml(chat_ai_file)
unless chat_ai.dig("gitops", "autoSync") == true &&
       chat_ai.dig("workload", "runtimeRole") == "chat-ai" &&
       chat_ai["replicaCount"] == 2 &&
       chat_ai.dig("container", "port") == 8000 &&
       chat_ai.dig("deployment", "terminationGracePeriodSeconds") == 120 &&
       chat_ai.dig("service", "enabled") == true &&
       chat_ai.dig("service", "port") == 80 &&
       chat_ai.dig("routing", "enabled") == false &&
       chat_ai.dig("pdb", "maxUnavailable") == 1 &&
       chat_ai.dig("secrets", "rolloutOnChange") == true &&
       chat_ai.dig("secrets", "secretProviderClassName") == "chat-ai" &&
       File.file?("platform/dev/networking/policies/chat-ai-egress.yaml")
  abort "#{chat_ai_file}: Chat AI의 Auto Sync·Replica·내부 Service·PDB·Secret·egress 설정이 필요합니다."
end

chat_ai_parameter_names = chat_ai.dig("secrets", "parameters", "objects").to_s.scan(%r{objectName: (/[A-Za-z0-9_./-]+)}).flatten
expected_chat_ai_parameters = %w[
  /lookddak/dev/v3/postgresql/app/database-url
  /lookddak/dev/v3/postgresql/app/checkpoint-dsn
  /lookddak/dev/internal/ai-api-key
  /lookddak/dev/fastapi/runware-llm-api-key
  /lookddak/dev/fastapi/runware-vton-api-key
  /lookddak/dev/fastapi/openAI-api-key
]
unless chat_ai_parameter_names == expected_chat_ai_parameters
  abort "#{chat_ai_file}: Chat AI Parameter 목록은 실제 V3 IRSA 정책과 같아야 합니다."
end


# Commerce 도메인: API 2개 Pod와 apply/deliver CronJob 2개를 한 PR에서 함께 활성화한다.
commerce_api_file = "environments/dev/domains/commerce/workloads/commerce-api.yaml"
commerce_api = load_yaml(commerce_api_file)
unless commerce_api.dig("gitops", "autoSync") == true &&
       commerce_api.dig("workload", "runtimeRole") == "commerce-api" &&
       commerce_api["replicaCount"] == 2 &&
       commerce_api.dig("container", "port") == 8080 &&
       commerce_api.dig("service", "enabled") == true &&
       commerce_api.dig("service", "port") == 80 &&
       commerce_api.dig("pdb", "maxUnavailable") == 1 &&
       commerce_api.dig("secrets", "secretProviderClassName") == "commerce-api" &&
       File.file?("platform/dev/networking/policies/commerce-api-egress.yaml")
  abort "#{commerce_api_file}: Commerce API의 Auto Sync·Replica·Port·PDB·Secret 설정이 필요합니다."
end

commerce_parameter_names = commerce_api.dig("secrets", "parameters", "objects").to_s.scan(%r{objectName: (/[A-Za-z0-9_./-]+)}).flatten
expected_commerce_parameters = %w[
  /lookddak/dev/v3/mysql/jdbc-url
  /lookddak/dev/v3/mysql/app/username
  /lookddak/dev/v3/mysql/app/password
  /lookddak/dev/spring/jwt-secret
  /lookddak/dev/spring/internal-api-key
]
unless commerce_parameter_names == expected_commerce_parameters
  abort "#{commerce_api_file}: Commerce API Parameter 목록은 실제 V3 IRSA 정책과 같아야 합니다."
end

price_crawler_file = "environments/dev/domains/commerce/workloads/price-crawler.yaml"
price_crawler = load_yaml(price_crawler_file)
cron_job = price_crawler.fetch("cronJob")
expected_cron_safety = {
  "timeZone" => "Asia/Seoul",
  "suspend" => false,
  "concurrencyPolicy" => "Forbid",
  "startingDeadlineSeconds" => 3600,
  "successfulJobsHistoryLimit" => 1,
  "failedJobsHistoryLimit" => 3,
  "backoffLimit" => 3,
  "activeDeadlineSeconds" => 3600,
  "restartPolicy" => "Never"
}
unless price_crawler.dig("gitops", "autoSync") == true &&
       price_crawler.dig("container", "env")&.include?({ "name" => "PRICE_REFRESH_BACKEND_BASE_URL", "value" => "http://commerce-api" }) &&
       price_crawler.dig("secrets", "secretProviderClassName") == "price-crawler" &&
       File.file?("platform/dev/networking/policies/price-crawler-egress.yaml") &&
       cron_job["nameSuffix"] == "apply" &&
       cron_job["schedule"] == "0 11 * * *" &&
       expected_cron_safety.all? { |key, value| cron_job[key] == value } &&
       price_crawler.dig("secrets", "startup", "command") == %w[python -m price_refresh --apply] &&
       cron_job["extraJobs"] == [{
         "nameSuffix" => "deliver",
         "schedule" => "40 11,13 * * *",
         "command" => %w[python -m price_refresh --deliver]
       }]
  abort "#{price_crawler_file}: apply/deliver CronJob 일정·명령·안전 설정이 설계와 다릅니다."
end

crawler_parameter_names = price_crawler.dig("secrets", "parameters", "objects").to_s.scan(%r{objectName: (/[A-Za-z0-9_./-]+)}).flatten
unless crawler_parameter_names == %w[/lookddak/dev/v3/postgresql/app/database-url /lookddak/dev/internal/price-refresh-backend-auth-headers]
  abort "#{price_crawler_file}: Crawler Parameter 목록은 실제 V3 IRSA 정책과 같아야 합니다."
end

# Fitting 도메인: API, BE Queue Worker, AI Orchestrator를 역할별로 분리해 한 PR에서 활성화한다.
be_request_queue_url = "https://sqs.ap-northeast-2.amazonaws.com/686496667254/lookddak-dev-v3-be-fitting-request"
ai_response_queue_url = "https://sqs.ap-northeast-2.amazonaws.com/686496667254/lookddak-dev-v3-ai-fitting-response"
be_response_queue_url = "https://sqs.ap-northeast-2.amazonaws.com/686496667254/lookddak-dev-v3-be-fitting-response"

fitting_api_file = "environments/dev/domains/fitting/workloads/fitting-api.yaml"
fitting_api = load_yaml(fitting_api_file)
unless fitting_api.dig("gitops", "autoSync") == true &&
       fitting_api.dig("workload", "runtimeRole") == "fitting-api" &&
       fitting_api["replicaCount"] == 2 &&
       fitting_api.dig("container", "port") == 8080 &&
       fitting_api.dig("deployment", "terminationGracePeriodSeconds") == 330 &&
       fitting_api.dig("service", "enabled") == true &&
       fitting_api.dig("service", "port") == 80 &&
       fitting_api.dig("routing", "enabled") == true &&
       fitting_api.dig("pdb", "maxUnavailable") == 1 &&
       fitting_api.dig("secrets", "secretProviderClassName") == "fitting-api" &&
       fitting_api.dig("container", "env")&.include?({ "name" => "FITTING_OUTBOX_ENABLED", "value" => "false" }) &&
       fitting_api.dig("container", "env")&.include?({ "name" => "FITTING_RESULT_CONSUMER_ENABLED", "value" => "false" }) &&
       File.file?("platform/dev/networking/policies/fitting-api-egress.yaml")
  abort "#{fitting_api_file}: Fitting API의 Auto Sync·Replica·SSE 종료·Worker 비활성·Secret 설정이 필요합니다."
end

fitting_api_parameter_names = fitting_api.dig("secrets", "parameters", "objects").to_s.scan(%r{objectName: (/[A-Za-z0-9_./-]+)}).flatten
expected_fitting_api_parameters = %w[
  /lookddak/dev/v3/mysql/jdbc-url
  /lookddak/dev/v3/mysql/app/username
  /lookddak/dev/v3/mysql/app/password
  /lookddak/dev/spring/jwt-secret
  /lookddak/dev/internal/ai-api-key
]
unless fitting_api_parameter_names == expected_fitting_api_parameters
  abort "#{fitting_api_file}: Fitting API Parameter 목록은 실제 V3 IRSA 정책과 같아야 합니다."
end

fitting_worker_file = "environments/dev/domains/fitting/workloads/fitting-worker.yaml"
fitting_worker = load_yaml(fitting_worker_file)
unless fitting_worker.dig("gitops", "autoSync") == true &&
       fitting_worker.dig("workload", "runtimeRole") == "fitting-worker" &&
       fitting_worker["replicaCount"] == 2 &&
       fitting_worker.dig("container", "port") == 8080 &&
       fitting_worker.dig("deployment", "terminationGracePeriodSeconds") == 120 &&
       fitting_worker.dig("service", "enabled") == false &&
       fitting_worker.dig("routing", "enabled") == false &&
       fitting_worker.dig("pdb", "maxUnavailable") == 1 &&
       fitting_worker.dig("secrets", "secretProviderClassName") == "fitting-worker" &&
       fitting_worker.dig("container", "env")&.include?({ "name" => "BE_FITTING_REQUEST_QUEUE_URL", "value" => be_request_queue_url }) &&
       fitting_worker.dig("container", "env")&.include?({ "name" => "BE_FITTING_RESPONSE_QUEUE_URL", "value" => be_response_queue_url }) &&
       fitting_worker.dig("container", "env")&.include?({ "name" => "FITTING_OUTBOX_ENABLED", "value" => "true" }) &&
       fitting_worker.dig("container", "env")&.include?({ "name" => "FITTING_RESULT_CONSUMER_ENABLED", "value" => "true" }) &&
       File.file?("platform/dev/networking/policies/fitting-worker-egress.yaml")
  abort "#{fitting_worker_file}: Fitting Worker의 Auto Sync·V3 Queue·Worker 활성·Secret 설정이 필요합니다."
end

fitting_worker_parameter_names = fitting_worker.dig("secrets", "parameters", "objects").to_s.scan(%r{objectName: (/[A-Za-z0-9_./-]+)}).flatten
expected_fitting_worker_parameters = %w[
  /lookddak/dev/v3/mysql/jdbc-url
  /lookddak/dev/v3/mysql/app/username
  /lookddak/dev/v3/mysql/app/password
  /lookddak/dev/spring/jwt-secret
]
unless fitting_worker_parameter_names == expected_fitting_worker_parameters
  abort "#{fitting_worker_file}: Fitting Worker Parameter 목록은 실제 V3 IRSA 정책과 같아야 합니다."
end

vton_file = "environments/dev/domains/fitting/workloads/vton-orchestrator.yaml"
vton = load_yaml(vton_file)
vton_env = vton.dig("container", "env") || []
required_vton_flags = %w[
  VIRTUAL_FITTING_REQUEST_WORKER_ENABLED
  VIRTUAL_FITTING_POSTPROCESS_WORKER_ENABLED
  VIRTUAL_FITTING_RESULT_PUBLISHER_ENABLED
  VIRTUAL_FITTING_WATCHDOG_ENABLED
]
unless vton.dig("gitops", "autoSync") == true &&
       vton.dig("workload", "runtimeRole") == "vton-orchestrator" &&
       vton["replicaCount"] == 2 &&
       vton.dig("container", "port") == 8000 &&
       vton.dig("deployment", "terminationGracePeriodSeconds") == 330 &&
       vton.dig("service", "enabled") == true &&
       vton.dig("service", "port") == 80 &&
       vton.dig("routing", "enabled") == true &&
       vton.dig("pdb", "maxUnavailable") == 1 &&
       vton.dig("secrets", "rolloutOnChange") == true &&
       vton.dig("secrets", "secretProviderClassName") == "vton-orchestrator" &&
       vton_env.include?({ "name" => "BE_FITTING_REQUEST_QUEUE_URL", "value" => be_request_queue_url }) &&
       vton_env.include?({ "name" => "AI_FITTING_RESPONSE_QUEUE_URL", "value" => ai_response_queue_url }) &&
       vton_env.include?({ "name" => "BE_FITTING_RESPONSE_QUEUE_URL", "value" => be_response_queue_url }) &&
       required_vton_flags.all? { |name| vton_env.include?({ "name" => name, "value" => "true" }) } &&
       vton.dig("secrets", "startup", "command").join(" ").include?("https://v3-dev.lookddak.com/api/v2/webhooks/runware?token=${WEBHOOK_TOKEN}") &&
       File.file?("platform/dev/networking/policies/vton-orchestrator-egress.yaml")
  abort "#{vton_file}: VTON Orchestrator의 Auto Sync·V3 Queue·Worker·Webhook·Secret 설정이 필요합니다."
end

vton_parameter_names = vton.dig("secrets", "parameters", "objects").to_s.scan(%r{objectName: (/[A-Za-z0-9_./-]+)}).flatten
expected_vton_parameters = %w[
  /lookddak/dev/v3/postgresql/app/database-url
  /lookddak/dev/internal/ai-api-key
  /lookddak/dev/fastapi/runware-vton-api-key
  /lookddak/dev/fastapi/runware-llm-api-key
  /lookddak/dev/fastapi/webhook-token
]
unless vton_parameter_names == expected_vton_parameters
  abort "#{vton_file}: VTON Orchestrator는 V3 Callback에 필요한 최소 Parameter만 마운트해야 합니다."
end

# web-bff → BE는 lookddak-web waypoint를 거친다 (platform/dev/networking/internal-api)
# 도메인 Namespace에 web-bff 신원을 직접 허용하지 않는다
Dir["environments/dev/domains/*/domain.yaml"].sort.each do |file|
  direct = (load_yaml(file).dig("authorizationPolicy", "workloadIngress") || []).select { |item| item["sourcePrincipal"] == "cluster.local/ns/lookddak-web/sa/web-bff" }
  abort "#{file}: web-bff는 waypoint 경유로 호출하므로 web-bff 신원을 직접 허용하지 않습니다: #{direct.map { |item| item['name'] }}" unless direct.empty?
end


storage_class = load_yaml("platform/dev/storage/storageclass-gp3.yaml")
unless storage_class["kind"] == "StorageClass" && storage_class.dig("metadata", "name") == "gp3" &&
       storage_class.dig("metadata", "annotations", "storageclass.kubernetes.io/is-default-class") == "true" &&
       storage_class["provisioner"] == "ebs.csi.aws.com" &&
       storage_class["parameters"] == { "type" => "gp3", "encrypted" => "true", "csi.storage.k8s.io/fstype" => "ext4" } &&
       storage_class["volumeBindingMode"] == "WaitForFirstConsumer" && storage_class["reclaimPolicy"] == "Delete"
  abort "platform/dev/storage/storageclass-gp3.yaml: 기본 StorageClass는 EBS CSI 암호화 gp3, WaitForFirstConsumer여야 합니다."
end

monitoring_namespace = load_yaml("argocd/dev/namespace-monitoring.yaml")
abort "argocd/dev/namespace-monitoring.yaml: monitoring Namespace는 Ambient에 등록하지 않습니다." if (monitoring_namespace.dig("metadata", "labels") || {}).key?("istio.io/dataplane-mode")

monitoring_dependencies = {
  "prometheus" => ["29.45.1", "https://prometheus-community.github.io/helm-charts"],
  "loki" => ["7.5.0", "https://grafana.github.io/helm-charts"],
  "tempo" => ["3.2.1", "https://grafana-community.github.io/helm-charts"]
}.freeze
monitoring_collector_dependencies = {
  "alloy-node" => ["alloy", "1.15.0", "https://grafana.github.io/helm-charts"],
  "kube-state-metrics" => ["kube-state-metrics", "9.0.0", "https://prometheus-community.github.io/helm-charts"],
  "alloy-cluster" => ["alloy", "1.15.0", "https://grafana.github.io/helm-charts"]
}.freeze
monitoring_toleration = [{ "key" => "dedicated", "operator" => "Equal", "value" => "monitoring", "effect" => "NoSchedule" }].freeze
monitoring_node_selector = { "lookddak.io/node-pool" => "monitoring" }.freeze
monitoring_dependencies.each do |chart, (version, repository)|
  chart_file = "platform/dev/observability/#{chart}/Chart.yaml"
  dependency = (load_yaml(chart_file)["dependencies"] || []).find { |item| item["name"] == chart }
  abort "#{chart_file}: #{chart} #{version} 의존성을 고정해야 합니다." unless dependency && dependency["version"] == version && dependency["repository"] == repository

  file = "argocd/dev/#{chart}-application.yaml"
  application = load_yaml(file)
  unless application.dig("metadata", "name") == "lookddak-dev-#{chart}" &&
         application.dig("spec", "project") == "lookddak-dev-platform" &&
         application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "1" &&
         application.dig("spec", "source") == { "repoURL" => gitops_repository, "targetRevision" => "main", "path" => "platform/dev/observability/#{chart}", "helm" => { "releaseName" => chart } } &&
         application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "monitoring" }
    abort "#{file}: #{chart} Application 설정이 예상과 다릅니다."
  end
end

prometheus_values = load_yaml("platform/dev/observability/prometheus/values.yaml").fetch("prometheus")
prometheus_server = prometheus_values.fetch("server")
unless prometheus_values.dig("configmapReload", "prometheus", "image", "tag") == "v0.94.0"
  abort "platform/dev/observability/prometheus/values.yaml: config-reloader는 arm64 이미지가 있는 v0.94.0으로 고정해야 합니다 (v0.95.x는 arm64 없음)."
end
unless %w[alertmanager kube-state-metrics prometheus-node-exporter prometheus-pushgateway].all? { |name| prometheus_values.dig(name, "enabled") == false } &&
       prometheus_server.fetch("extraFlags").include?("web.enable-remote-write-receiver") &&
       prometheus_server["retention"] == "7d" &&
       prometheus_server["persistentVolume"] == { "enabled" => true, "size" => "30Gi", "storageClass" => "gp3" } &&
       prometheus_server["nodeSelector"] == monitoring_node_selector && prometheus_server["tolerations"] == monitoring_toleration &&
       prometheus_values.fetch("scrapeConfigs").values.all? { |job| job["enabled"] == false }
  abort "platform/dev/observability/prometheus/values.yaml: Prometheus는 부가 구성 비활성, remote write 수신, 보존 7일, gp3 30Gi, 모니터링 노드 배치, 기본 수집 비활성이 필요합니다."
end

loki_values = load_yaml("platform/dev/observability/loki/values.yaml").fetch("loki")
loki_bucket = "lookddak-dev-v3-loki-686496667254-ap-northeast-2"
unless loki_values["deploymentMode"] == "SingleBinary" &&
       loki_values.dig("serviceAccount", "name") == "loki" &&
       loki_values.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-dev-v3-loki" &&
       loki_values.dig("loki", "storage", "bucketNames", "chunks") == loki_bucket &&
       loki_values.dig("loki", "limits_config", "retention_period") == "168h" &&
       loki_values.dig("loki", "compactor", "retention_enabled") == true &&
       loki_values.dig("singleBinary", "replicas") == 1 &&
       %w[read write backend].all? { |target| loki_values.dig(target, "replicas") == 0 } &&
       loki_values.dig("singleBinary", "persistence", "storageClass") == "gp3" &&
       loki_values.dig("singleBinary", "nodeSelector") == monitoring_node_selector && loki_values.dig("singleBinary", "tolerations") == monitoring_toleration
  abort "platform/dev/observability/loki/values.yaml: Loki는 SingleBinary 1개, IRSA·S3 버킷, 보존 7일, gp3, 모니터링 노드 배치가 필요합니다."
end

tempo_values = load_yaml("platform/dev/observability/tempo/values.yaml").fetch("tempo")
unless tempo_values.dig("serviceAccount", "name") == "tempo" &&
       tempo_values.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-dev-v3-tempo" &&
       tempo_values.dig("tempo", "storage", "trace", "backend") == "s3" &&
       tempo_values.dig("tempo", "storage", "trace", "s3", "bucket") == "lookddak-dev-v3-tempo-686496667254-ap-northeast-2" &&
       tempo_values.dig("tempo", "retention") == "168h" &&
       tempo_values.dig("persistence", "storageClassName") == "gp3" &&
       tempo_values["nodeSelector"] == monitoring_node_selector && tempo_values["tolerations"] == monitoring_toleration
  abort "platform/dev/observability/tempo/values.yaml: Tempo는 IRSA·S3 버킷, 보존 7일, gp3, 모니터링 노드 배치가 필요합니다."
end


monitoring_collector_dependencies.each do |chart, (dependency_name, version, repository)|
  chart_file = "platform/dev/observability/#{chart}/Chart.yaml"
  dependency = (load_yaml(chart_file)["dependencies"] || []).find { |item| item["name"] == dependency_name }
  abort "#{chart_file}: #{dependency_name} #{version} 의존성을 고정해야 합니다." unless dependency && dependency["version"] == version && dependency["repository"] == repository

  file = "argocd/dev/#{chart}-application.yaml"
  application = load_yaml(file)
  unless application.dig("metadata", "name") == "lookddak-dev-#{chart}" &&
         application.dig("spec", "project") == "lookddak-dev-platform" &&
         application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "2" &&
         application.dig("spec", "source") == { "repoURL" => gitops_repository, "targetRevision" => "main", "path" => "platform/dev/observability/#{chart}", "helm" => { "releaseName" => chart } } &&
         application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "monitoring" }
    abort "#{file}: #{chart} Application 설정이 예상과 다릅니다."
  end
end

alloy_node_values = load_yaml("platform/dev/observability/alloy-node/values.yaml").fetch("alloy")
alloy_node_config = alloy_node_values.dig("alloy", "configMap", "content").to_s
unless alloy_node_values.dig("controller", "type") == "daemonset" &&
       alloy_node_values.dig("controller", "tolerations") == [{ "operator" => "Exists" }] &&
       !(alloy_node_values.dig("controller", "podLabels") || {}).key?("istio.io/dataplane-mode") &&
       alloy_node_values.dig("crds", "create") == false &&
       alloy_node_config.include?('field = "spec.nodeName=" + sys.env("NODE_NAME")') &&
       alloy_node_config.include?("http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push") &&
       alloy_node_config.include?("http://prometheus-server.monitoring.svc.cluster.local/api/v1/write")
  abort "platform/dev/observability/alloy-node/values.yaml: Alloy Node는 메시 밖 DaemonSet(전체 Toleration), 자기 노드 Pod만 수집, Loki·Prometheus 클러스터 주소 전송이 필요합니다."
end

ksm_values = load_yaml("platform/dev/observability/kube-state-metrics/values.yaml").fetch("kube-state-metrics")
unless ksm_values["nodeSelector"] == monitoring_node_selector && ksm_values["tolerations"] == monitoring_toleration
  abort "platform/dev/observability/kube-state-metrics/values.yaml: kube-state-metrics는 Monitoring Node에 배치해야 합니다."
end


alloy_cluster_values = load_yaml("platform/dev/observability/alloy-cluster/values.yaml").fetch("alloy")
alloy_cluster_principal = "cluster.local/ns/monitoring/sa/alloy-cluster"
unless alloy_cluster_values.dig("controller", "type") == "deployment" &&
       alloy_cluster_values.dig("controller", "replicas") == 1 &&
       alloy_cluster_values.dig("controller", "podLabels", "istio.io/dataplane-mode") == "ambient" &&
       alloy_cluster_values.dig("serviceAccount", "name") == "alloy-cluster" &&
       alloy_cluster_values.dig("controller", "nodeSelector") == monitoring_node_selector &&
       alloy_cluster_values.dig("controller", "tolerations") == monitoring_toleration &&
       alloy_cluster_values.dig("crds", "create") == false
  abort "platform/dev/observability/alloy-cluster/values.yaml: Alloy Cluster는 Deployment 1개, Pod 단위 Ambient 등록, SA alloy-cluster, Monitoring Node 배치가 필요합니다."
end
alloy_cluster_config = alloy_cluster_values.dig("alloy", "configMap", "content").to_s
alloy_memory_limiter = alloy_cluster_config[/otelcol\.processor\.memory_limiter[^{]*\{(.*?)\n\s*output/m, 1].to_s
unless alloy_memory_limiter.match?(/^\s*limit_percentage\s*=\s*\d+/) && alloy_memory_limiter.match?(/^\s*spike_limit_percentage\s*=\s*\d+/)
  abort "platform/dev/observability/alloy-cluster/values.yaml: otelcol.processor.memory_limiter는 limit_percentage와 spike_limit_percentage를 함께 지정해야 합니다."
end

domain_chart_values = load_yaml("charts/lookddak-domain/values.yaml")
unless domain_chart_values.dig("authorizationPolicy", "metricsScrape", "principal") == alloy_cluster_principal &&
       domain_chart_values.dig("authorizationPolicy", "metricsScrape", "ports") == %w[8080 8000]
  abort "charts/lookddak-domain/values.yaml: 메트릭 수집 인가는 alloy-cluster 신원과 8080·8000 포트만 허용해야 합니다."
end
Dir["environments/dev/domains/*/domain.yaml"].sort.each do |file|
  abort "#{file}: dev 도메인은 Alloy Cluster 메트릭 수집 인가(authorizationPolicy.metricsScrape.enabled)가 필요합니다." unless load_yaml(file).dig("authorizationPolicy", "metricsScrape", "enabled") == true
end

alloy_scrape_policy = load_yaml("platform/dev/networking/policies/alloy-cluster-scrape.yaml")
alloy_scrape_ports = Array(alloy_scrape_policy.dig("spec", "ingress")).flat_map { |rule| Array(rule["toPorts"]).flat_map { |port| Array(port["ports"]).map { |item| item["port"] } } }.sort
unless alloy_scrape_policy["kind"] == "CiliumClusterwideNetworkPolicy" &&
       alloy_scrape_policy.dig("spec", "endpointSelector") == baseline.dig("spec", "endpointSelector") &&
       alloy_scrape_policy.dig("spec", "ingress", 0, "fromEndpoints") == [{ "matchLabels" => { "k8s:io.kubernetes.pod.namespace" => "monitoring", "k8s:app.kubernetes.io/instance" => "alloy-cluster" } }] &&
       alloy_scrape_ports == %w[15008 15020] &&
       !alloy_scrape_policy.dig("spec", "egress")
  abort "platform/dev/networking/policies/alloy-cluster-scrape.yaml: 도메인 Pod는 monitoring/alloy-cluster에서 15008·15020만 받아야 합니다."
end

gateway_telemetry = load_yaml("platform/dev/networking/gateway/telemetry.yaml")
unless gateway_telemetry["kind"] == "Telemetry" &&
       gateway_telemetry.dig("metadata", "namespace") == "istio-ingress" &&
       gateway_telemetry.dig("spec", "targetRefs") == [{ "group" => "gateway.networking.k8s.io", "kind" => "Gateway", "name" => "lookddak-gateway" }] &&
       gateway_telemetry.dig("spec", "accessLogging") == [{ "providers" => [{ "name" => "envoy" }] }]
  abort "platform/dev/networking/gateway/telemetry.yaml: 공용 Gateway 액세스 로그 전부(envoy provider)를 켜야 합니다."
end

priority_class = load_yaml("platform/dev/scheduling/priority-classes.yaml")
unless priority_class["kind"] == "PriorityClass" && priority_class.dig("metadata", "name") == "lookddak-monitoring-storage" &&
       priority_class["globalDefault"] == false && priority_class["preemptionPolicy"] == "Never"
  abort "platform/dev/scheduling/priority-classes.yaml: lookddak-monitoring-storage는 기본값이 아니고 선점하지 않아야 합니다."
end
unless prometheus_server["priorityClassName"] == "lookddak-monitoring-storage" &&
       loki_values.dig("singleBinary", "priorityClassName") == "lookddak-monitoring-storage" &&
       tempo_values["priorityClassName"] == "lookddak-monitoring-storage"
  abort "Prometheus·Loki·Tempo는 PriorityClass lookddak-monitoring-storage가 필요합니다."
end
scheduling_application = load_yaml("argocd/dev/scheduling-application.yaml")
unless scheduling_application.dig("spec", "project") == "lookddak-dev-platform" &&
       scheduling_application.dig("spec", "source", "path") == "platform/dev/scheduling" &&
       scheduling_application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-1"
  abort "argocd/dev/scheduling-application.yaml: PriorityClass Application 설정이 예상과 다릅니다."
end


gateway_application = load_yaml("argocd/dev/istio-gateway-application.yaml")
gateway_include = gateway_application.dig("spec", "source", "directory", "include").to_s.delete("{}").split(",").sort
gateway_manifests = Dir["platform/dev/networking/gateway/*.yaml"].map { |file| File.basename(file) }.sort
unless gateway_include == gateway_manifests
  abort "argocd/dev/istio-gateway-application.yaml: directory.include가 platform/dev/networking/gateway의 매니페스트와 다릅니다. include=#{gateway_include}, 파일=#{gateway_manifests}"
end


db_log_tailer = load_yaml("platform/dev/observability/db-log-tailer/deployment.yaml")
db_log_tailer_pod = db_log_tailer.dig("spec", "template", "spec")
db_log_tailer_container = db_log_tailer_pod.fetch("containers").first
db_log_tailer_env = db_log_tailer_container.fetch("env").to_h { |item| [item["name"], item["value"]] }
unless db_log_tailer.dig("spec", "replicas") == 1 &&
       db_log_tailer.dig("spec", "strategy", "type") == "Recreate" &&
       db_log_tailer.dig("spec", "template", "metadata", "labels", "istio.io/dataplane-mode") == "ambient" &&
       db_log_tailer_pod["serviceAccountName"] == "db-log-tailer" &&
       db_log_tailer_pod["nodeSelector"] == monitoring_node_selector && db_log_tailer_pod["tolerations"] == monitoring_toleration &&
       db_log_tailer_container["image"].match?(%r{\A686496667254\.dkr\.ecr\.ap-northeast-2\.amazonaws\.com/lookddak-dev-v3-db-log-tailer@sha256:[0-9a-f]{64}\z}) &&
       db_log_tailer_env["LOKI_URL"] == "http://alloy-cluster.monitoring.svc.cluster.local:3500/loki/api/v1/push"
  abort "platform/dev/observability/db-log-tailer/deployment.yaml: db-log-tailer는 1개·Recreate, Ambient 등록, IRSA SA, Monitoring Node, ECR digest 고정, Alloy Cluster push가 필요합니다."
end
unless load_yaml("platform/dev/observability/db-log-tailer/serviceaccount.yaml").dig("metadata", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-dev-v3-db-log-tailer"
  abort "platform/dev/observability/db-log-tailer/serviceaccount.yaml: IRSA Role lookddak-dev-v3-db-log-tailer가 필요합니다."
end
unless alloy_cluster_config.include?("loki.source.api \"db_logs\"") && alloy_cluster_values.dig("alloy", "extraPorts").any? { |port| port["port"] == 3500 }
  abort "platform/dev/observability/alloy-cluster/values.yaml: db-log-tailer push를 받을 loki.source.api(3500)와 Service 포트가 필요합니다."
end
db_log_tailer_application = load_yaml("argocd/dev/db-log-tailer-application.yaml")
unless db_log_tailer_application.dig("spec", "project") == "lookddak-dev-platform" &&
       db_log_tailer_application.dig("spec", "source", "path") == "platform/dev/observability/db-log-tailer" &&
       db_log_tailer_application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "monitoring" }
  abort "argocd/dev/db-log-tailer-application.yaml: db-log-tailer Application 설정이 예상과 다릅니다."
end


unless alloy_cluster_values.dig("serviceAccount", "annotations", "eks.amazonaws.com/role-arn") == "arn:aws:iam::686496667254:role/lookddak-dev-v3-alloy-cluster" &&
       File.file?("platform/dev/observability/alloy-cluster/files/ap-northeast-2-bundle.pem") &&
       File.read("platform/dev/observability/alloy-cluster/files/ap-northeast-2-bundle.pem").include?("BEGIN CERTIFICATE")
  abort "platform/dev/observability/alloy-cluster: DB 지표 수집에는 IRSA lookddak-dev-v3-alloy-cluster와 RDS CA 번들(files/ap-northeast-2-bundle.pem)이 필요합니다."
end
unless alloy_cluster_config.include?('data_source_names = ["postgresql://exporter:"') && alloy_cluster_config.include?('string.replace(convert.nonsensitive(local.file.postgres_exporter_password.content), "%", "%25")')
  abort "platform/dev/observability/alloy-cluster/values.yaml: prometheus.exporter.postgres는 postgresql:// URL 형식과 비밀번호 URL 인코딩(% 먼저)이 필요합니다."
end
abort "platform/dev/observability/alloy-cluster/values.yaml: CloudWatch static 작업은 GetMetricStatistics 권한이 필요하므로 discovery만 사용합니다." if alloy_cluster_config.match?(/^\s*static "/)
unless alloy_cluster_config.include?('type                        = "AWS/RDS"') &&
       alloy_cluster_config.include?('type                        = "AWS/SQS"') && alloy_cluster_config.include?('search_tags                 = { "Environment" = "dev" }') && alloy_cluster_config.include?("decoupled_scraping {")
  abort "platform/dev/observability/alloy-cluster/values.yaml: CloudWatch는 dev 태그 SQS(V2·V3) discovery와 decoupled_scraping(5분 조회)이 필요합니다."
end
%w[__MYSQL_HOST__ __POSTGRES_HOST__].each do |placeholder|
  abort "platform/dev/observability/alloy-cluster/values.yaml: #{placeholder}를 RDS 엔드포인트로 바꿔야 합니다." if alloy_cluster_config.include?(placeholder)
end



grafana_dependency = (load_yaml("platform/dev/observability/grafana/Chart.yaml")["dependencies"] || []).find { |item| item["name"] == "grafana" }
unless grafana_dependency && grafana_dependency["version"] == "14.4.0" && grafana_dependency["repository"] == "https://grafana-community.github.io/helm-charts"
  abort "platform/dev/observability/grafana/Chart.yaml: grafana-community grafana 14.4.0 의존성을 고정해야 합니다."
end
grafana_application = load_yaml("argocd/dev/grafana-application.yaml")
unless grafana_application.dig("spec", "project") == "lookddak-dev-platform" &&
       grafana_application.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "3" &&
       grafana_application.dig("spec", "source") == { "repoURL" => gitops_repository, "targetRevision" => "main", "path" => "platform/dev/observability/grafana", "helm" => { "releaseName" => "grafana" } } &&
       grafana_application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "monitoring" }
  abort "argocd/dev/grafana-application.yaml: Grafana Application 설정이 예상과 다릅니다."
end
grafana_values = load_yaml("platform/dev/observability/grafana/values.yaml").fetch("grafana")
grafana_datasource_uids = grafana_values.dig("datasources", "datasources.yaml", "datasources").to_a.map { |item| item["uid"] }.sort
unless grafana_values.dig("env", "GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION") == "true" &&
       grafana_values.dig("grafana.ini", "auth", "disable_login_form") == true &&
       grafana_values.dig("persistence", "storageClassName") == "gp3" &&
       grafana_values["nodeSelector"] == monitoring_node_selector && grafana_values["tolerations"] == monitoring_toleration &&
       grafana_datasource_uids == %w[loki prometheus redis tempo] &&
       grafana_values.dig("podLabels", "istio.io/dataplane-mode") == "ambient" &&
       grafana_values.dig("dashboardsConfigMaps", "lookddak") == "grafana-dashboards-lookddak"
  abort "platform/dev/observability/grafana/values.yaml: Grafana는 관리자 계정·로그인 폼 미생성(Secret 없음), gp3, Monitoring Node, Pod 단위 Ambient, 데이터소스 4개(Redis 포함), LookDDak 대시보드 ConfigMap이 필요합니다."
end
grafana_dashboards = Dir["platform/dev/observability/grafana/files/dashboards/*.json"].sort
abort "platform/dev/observability/grafana/files/dashboards: 대시보드 JSON이 없습니다." if grafana_dashboards.empty?
grafana_dashboards.each do |file|
  dashboard = JSON.parse(File.read(file))
  abort "#{file}: 대시보드 uid는 파일 이름과 같아야 합니다." unless dashboard["uid"] == File.basename(file, ".json")
  datasource_uids = dashboard.fetch("panels").flat_map { |panel| [panel.dig("datasource", "uid")] + panel.fetch("targets", []).map { |target| target.dig("datasource", "uid") } }.compact.uniq
  abort "#{file}: 데이터소스는 provisioning uid(prometheus·loki·tempo)만 참조해야 합니다. 실제=#{datasource_uids}" unless (datasource_uids - %w[prometheus loki tempo]).empty?
end


grafana_host = "grafana.v3-dev.lookddak.com"
unless gateway_listeners.find { |item| item["name"] == "https-grafana" }&.dig("hostname") == grafana_host
  abort "platform/dev/networking/gateway/gateway.yaml: https-grafana Listener는 #{grafana_host}여야 합니다."
end
istiod_dev_values = load_yaml("platform/dev/networking/istio/istiod/values.yaml").fetch("istiod")
grafana_authz_provider = istiod_dev_values.dig("meshConfig", "extensionProviders").to_a.find { |item| item["name"] == "oauth2-proxy-grafana" }
unless grafana_authz_provider && grafana_authz_provider.dig("envoyExtAuthzHttp", "service") == "oauth2-proxy.monitoring.svc.cluster.local" && grafana_authz_provider.dig("envoyExtAuthzHttp", "port") == 4180 &&
       grafana_authz_provider.dig("envoyExtAuthzHttp", "headersToUpstreamOnAllow").to_a.include?("x-auth-request-email")
  abort "platform/dev/networking/istio/istiod/values.yaml: oauth2-proxy-grafana ext_authz provider(4180, x-auth-request-email 전달)가 필요합니다."
end
grafana_ext_authz = load_yaml("platform/dev/networking/gateway/grafana-ext-authz.yaml")
unless grafana_ext_authz["kind"] == "AuthorizationPolicy" && grafana_ext_authz.dig("spec", "action") == "CUSTOM" &&
       grafana_ext_authz.dig("spec", "provider", "name") == "oauth2-proxy-grafana" &&
       grafana_ext_authz.dig("spec", "targetRefs") == [{ "group" => "gateway.networking.k8s.io", "kind" => "Gateway", "name" => "lookddak-gateway" }] &&
       grafana_ext_authz.dig("spec", "rules", 0, "to", 0, "operation", "hosts").to_a.include?(grafana_host) &&
       grafana_ext_authz.dig("spec", "rules", 0, "to", 0, "operation", "notPaths") == ["/oauth2/*"]
  abort "platform/dev/networking/gateway/grafana-ext-authz.yaml: Grafana host는 /oauth2/*를 뺀 모든 경로가 oauth2-proxy ext_authz를 거쳐야 합니다."
end
grafana_auth_values = load_yaml("platform/dev/observability/grafana/values.yaml").fetch("grafana")
unless grafana_auth_values.dig("grafana.ini", "auth.proxy", "enabled") == true &&
       grafana_auth_values.dig("grafana.ini", "auth.proxy", "header_name") == "X-Auth-Request-Email" &&
       grafana_auth_values.dig("grafana.ini", "auth.anonymous", "enabled") == false
  abort "platform/dev/observability/grafana/values.yaml: Grafana는 auth.proxy(X-Auth-Request-Email)만 쓰고 익명 접속을 끕니다."
end
grafana_ingress_policies = YAML.load_stream(File.read("platform/dev/networking/policies/monitoring-grafana.yaml")).compact.to_h { |policy| [policy.dig("spec", "endpointSelector", "matchLabels", "k8s:app.kubernetes.io/name"), policy] }
gateway_endpoint = [{ "matchLabels" => { "k8s:io.kubernetes.pod.namespace" => "istio-ingress", "k8s:gateway.networking.k8s.io/gateway-name" => "lookddak-gateway" } }]
{ "oauth2-proxy" => "4180" }.each do |name, port|
  policy = grafana_ingress_policies[name]
  unless policy && policy.dig("metadata", "namespace") == "monitoring" && policy.dig("spec", "ingress") == [{ "fromEndpoints" => gateway_endpoint, "toPorts" => [{ "ports" => [{ "port" => port, "protocol" => "TCP" }] }] }]
    abort "platform/dev/networking/policies/monitoring-grafana.yaml: #{name}는 공용 Gateway에서 #{port}만 받아야 합니다 (auth.proxy 헤더 위조 방지)."
  end
end
grafana_cnp = grafana_ingress_policies["grafana"]
unless grafana_cnp && grafana_cnp.dig("metadata", "namespace") == "monitoring" &&
       grafana_cnp.dig("spec", "ingress") == [{ "fromCIDR" => ["169.254.7.127/32"] }, { "fromEndpoints" => gateway_endpoint, "toPorts" => [{ "ports" => [{ "port" => "15008", "protocol" => "TCP" }] }] }]
  abort "platform/dev/networking/policies/monitoring-grafana.yaml: Ambient Grafana는 공용 Gateway HBONE(15008)과 kubelet probe만 받아야 합니다 (auth.proxy 헤더 위조 방지)."
end
grafana_authz = YAML.load(File.read("platform/dev/observability/grafana/templates/authorization-policy.yaml").gsub("{{ .Release.Namespace }}", "monitoring"))
unless grafana_authz["kind"] == "AuthorizationPolicy" && grafana_authz.dig("spec", "action") == "ALLOW" &&
       grafana_authz.dig("spec", "selector", "matchLabels") == { "app.kubernetes.io/name" => "grafana" } &&
       grafana_authz.dig("spec", "rules") == [{ "from" => [{ "source" => { "principals" => ["cluster.local/ns/istio-ingress/sa/lookddak-gateway-istio"] } }], "to" => [{ "operation" => { "ports" => ["3000"] } }] }]
  abort "platform/dev/observability/grafana/templates/authorization-policy.yaml: Grafana 3000은 공용 Gateway 신원만 허용해야 합니다."
end
oauth2_proxy = load_yaml("platform/dev/observability/grafana-auth/deployment.yaml")
oauth2_proxy_args = oauth2_proxy.dig("spec", "template", "spec", "containers", 0, "args").to_a
unless oauth2_proxy_args.include?("--client-secret-file=/etc/oauth2-proxy/client-secret") && oauth2_proxy_args.include?("--cookie-secret-file=/etc/oauth2-proxy/cookie-secret") &&
       oauth2_proxy_args.include?("--set-xauthrequest=true") && oauth2_proxy_args.include?("--cookie-secure=true") &&
       oauth2_proxy_args.none? { |arg| arg.include?("__COGNITO_POOL_ID__") }
  abort "platform/dev/observability/grafana-auth/deployment.yaml: oauth2-proxy는 비밀값을 CSI 파일로 읽고, X-Auth-Request 헤더·secure 쿠키를 써야 합니다 (사용자 풀 ID 치환 필요)."
end

prod_placeholder_files = Dir["platform/prod/**/*.{yaml,yml}"].select { |file| File.read(file).match?(/__PROD_COGNITO_[A-Z_]+__|__REDIS_READONLY_ACL_RULE__/) }
abort "Prod 값이 비어 있습니다 (CLOUD terraform output으로 채우세요): #{prod_placeholder_files.join(', ')}" unless prod_placeholder_files.empty?
prod_redis_acl_lines = load_yaml("platform/prod/redis/cluster/redis-cluster-config.yaml").dig("data", "redis-additional.conf").to_s.lines.map(&:strip).select { |line| line.start_with?("user ") }
unless prod_redis_acl_lines.size == 1 && prod_redis_acl_lines[0].match?(/\Auser be-readonly on #[0-9a-f]{64} ~\* resetchannels -@all \+@read \+@connection .*-@dangerous \+info\z/) &&
       prod_redis_acl_lines[0] != redis_acl_lines[0]
  abort "platform/prod/redis/cluster/redis-cluster-config.yaml: Prod Redis ACL은 be-readonly 읽기 전용 사용자 하나이고 dev와 다른 비밀번호 해시여야 합니다."
end
prod_grafana_values = load_yaml("platform/prod/observability/grafana/values.yaml").fetch("grafana")
unless prod_grafana_values.dig("grafana.ini", "auth.proxy", "enabled") == true && prod_grafana_values.dig("grafana.ini", "auth.anonymous", "enabled") == false &&
       prod_grafana_values.dig("grafana.ini", "server", "root_url") == "https://grafana.v3-prod.lookddak.com" &&
       prod_grafana_values.dig("podLabels", "istio.io/dataplane-mode") == "ambient"
  abort "platform/prod/observability/grafana/values.yaml: Prod Grafana는 auth.proxy만, grafana.v3-prod, Pod 단위 Ambient여야 합니다."
end
prod_grafana_app = load_yaml("argocd/prod/platform/grafana-application.yaml")
abort "argocd/prod/platform/grafana-application.yaml: 대시보드 ConfigMap 크기 때문에 ServerSideApply=true가 필요합니다." unless prod_grafana_app.dig("spec", "syncPolicy", "syncOptions").to_a.include?("ServerSideApply=true")
prod_monitoring_text = Dir["platform/prod/{observability,redis,storage,scheduling}/**/*.{yaml,tpl}"].reject { |file| file.end_with?("crds.yaml") }.map { |file| [file, File.read(file)] }
prod_dev_refs = prod_monitoring_text.select { |file, text| text.gsub("lookddak-dev-v3-db-log-tailer@", "").match?(/lookddak-dev|v3-dev|\/lookddak\/dev\/|"Environment" = "dev"/) }.map(&:first)
abort "Prod 모니터링 구성에 dev 값이 남아 있습니다: #{prod_dev_refs.join(', ')}" unless prod_dev_refs.empty?

puts "저장소 구조 검사 완료: Argo CD·Karpenter·Metrics Server 플랫폼, dev Namespace 5개, 도메인 5개, 환경별 워크로드 10개, Application 이름 #{application_names.length}개"
