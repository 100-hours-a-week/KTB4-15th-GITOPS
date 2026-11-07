#!/usr/bin/env ruby

require "yaml"

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

argocd_files = %w[
  platform/dev/argocd/Chart.yaml
  platform/dev/argocd/Chart.lock
  platform/dev/argocd/values.yaml
  platform/dev/argocd/README.md
  platform/dev/argocd/system-node-isolation.md
  argocd/projects/lookddak-dev-argocd.yaml
  argocd/dev/argocd-application.yaml
].freeze

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
  platform/dev/networking/policies/web-waypoint.yaml
  argocd/dev/internal-api-application.yaml
].freeze

[argocd_files, karpenter_files, metrics_server_files, secrets_store_csi_files, aws_load_balancer_controller_files, istio_files, cert_manager_files, istio_gateway_files, network_policy_files, mesh_security_files, internal_api_files].flatten.each do |file|
  abort "필수 파일 누락: #{file}" unless File.file?(file)
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
unless argocd_project.dig("spec", "sourceRepos") == [gitops_repository] && argocd_project.dig("spec", "destinations") == [{ "server" => in_cluster_server, "namespace" => "argocd" }]
  abort "#{argocd_project_file}: Argo CD 전용 Project는 GitOps 저장소와 현재 Cluster의 argocd Namespace만 허용해야 합니다."
end
unless argocd_project.dig("metadata", "annotations", "argocd.argoproj.io/sync-wave") == "-2"
  abort "Argo CD 전용 Project는 Application보다 먼저 선언해야 합니다."
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

platform_project_file = "argocd/projects/lookddak-dev-platform.yaml"
platform_project = load_yaml(platform_project_file)
abort "#{platform_project_file}: kind가 AppProject가 아닙니다." unless platform_project["kind"] == "AppProject"
abort "#{platform_project_file}: Project 이름이 예상과 다릅니다." unless platform_project.dig("metadata", "name") == "lookddak-dev-platform"
abort "#{platform_project_file}: 허용 Repository가 예상과 다릅니다." unless platform_project.dig("spec", "sourceRepos") == [gitops_repository]

platform_destinations = platform_project.dig("spec", "destinations")
unless platform_destinations == %w[kube-system istio-system istio-ingress].map { |namespace| { "server" => in_cluster_server, "namespace" => namespace } }
  abort "#{platform_project_file}: 플랫폼 배포 대상은 현재 Cluster의 kube-system·istio-system·istio-ingress Namespace여야 합니다."
end

expected_platform_resources = [
  { "group" => "apiextensions.k8s.io", "kind" => "CustomResourceDefinition" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRole" },
  { "group" => "rbac.authorization.k8s.io", "kind" => "ClusterRoleBinding" },
  { "group" => "apiregistration.k8s.io", "kind" => "APIService" },
  { "group" => "storage.k8s.io", "kind" => "CSIDriver" },
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
unless nodepool_application.dig("spec", "source", "directory", "include") == "{ec2-nodeclass.yaml,nodepool.yaml}"
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

platform_namespaces = %w[istio-system istio-ingress].freeze
unless actual_dev_namespaces == (dev_namespaces + platform_namespaces).sort
  abort "dev Namespace 구성이 설계와 다릅니다. 예상=#{(dev_namespaces + platform_namespaces).sort}, 실제=#{actual_dev_namespaces}"
end

# 도메인 Namespace만 Istio Ambient에 등록한다 (플랫폼 Namespace는 메시 밖)
dev_namespace_files.each do |file|
  labels = load_yaml(file).dig("metadata", "labels") || {}
  if labels.key?("lookddak.com/domain")
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
internal_application = load_yaml("argocd/dev/internal-api-application.yaml")
unless internal_application.dig("spec", "project") == "lookddak-dev" &&
       internal_application.dig("spec", "source", "path") == "platform/dev/networking/internal-api" &&
       internal_application.dig("spec", "destination") == { "server" => in_cluster_server, "namespace" => "lookddak-web" }
  abort "argocd/dev/internal-api-application.yaml: 내부 API Application 설정이 예상과 다릅니다."
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
unless crawler_parameter_names == %w[/lookddak/dev/v2/postgresql/app/database-url /lookddak/dev/internal/price-refresh-backend-auth-headers]
  abort "#{price_crawler_file}: Crawler Parameter 목록은 실제 V3 IRSA 정책과 같아야 합니다."
end

commerce_domain = load_yaml("environments/dev/domains/commerce/domain.yaml")
unless commerce_domain.dig("authorizationPolicy", "workloadIngress") == [{
  "name" => "allow-web-bff-to-commerce-api",
  "targetWorkload" => "commerce-api",
  "sourcePrincipal" => "cluster.local/ns/lookddak-web/sa/web-bff",
  "targetPort" => "8080"
}]
  abort "Commerce API에는 web-bff ServiceAccount의 내부 API 호출만 추가 허용해야 합니다."
end

puts "저장소 구조 검사 완료: Argo CD·Karpenter·Metrics Server 플랫폼, dev Namespace 5개, 도메인 5개, 환경별 워크로드 10개, Application 이름 #{application_names.length}개"
