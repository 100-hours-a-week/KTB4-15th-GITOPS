#!/usr/bin/env ruby

require "yaml"

abort "사용법: #{$PROGRAM_NAME} <렌더링된 Argo CD Manifest> [dev|prod]" unless (1..2).cover?(ARGV.length)
environment = ARGV[1] || "dev"
abort "환경은 dev 또는 prod만 허용합니다." unless %w[dev prod].include?(environment)
resources = YAML.load_stream(File.read(ARGV[0])).compact
expected_toleration = { "key" => "CriticalAddonsOnly", "operator" => "Equal", "value" => "true", "effect" => "NoSchedule" }
expected_pods = %w[
  argocd-application-controller
  argocd-applicationset-controller
  argocd-notifications-controller
  argocd-redis
  argocd-repo-server
  argocd-server
  argocd-redis-secret-init
]
pod_resources = resources.select { |item| %w[Deployment StatefulSet DaemonSet Job].include?(item["kind"]) }
unless pod_resources.map { |item| item.dig("metadata", "name") }.sort == expected_pods.sort
  abort "Argo CD 전환 중 활성 구성요소·Hook 구성이 변경되었습니다."
end
pod_resources.each do |item|
  name = item.dig("metadata", "name")
  pod = item.dig("spec", "template", "spec")
  unless pod.dig("nodeSelector", "lookddak.io/node-pool") == "system" && (pod["tolerations"] || []).include?(expected_toleration)
    abort "#{name}: System Node 고정과 CriticalAddonsOnly Toleration이 필요합니다."
  end
end

crds = resources.select { |item| item["kind"] == "CustomResourceDefinition" }
expected_crds = %w[applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io]
abort "Argo CD CRD 3개가 필요합니다." unless crds.map { |item| item.dig("metadata", "name") }.sort == expected_crds.sort
crds.each do |item|
  options = item.dig("metadata", "annotations", "argocd.argoproj.io/sync-options").to_s.split(",")
  unless %w[ServerSideApply=true Prune=false Delete=false].all? { |option| options.include?(option) } && item.dig("metadata", "annotations", "helm.sh/resource-policy") == "keep"
    abort "Argo CD CRD에는 Server Side Apply·삭제 방지 설정이 필요합니다."
  end
end
secrets = resources.select { |item| item["kind"] == "Secret" }
unless secrets.map { |item| item.dig("metadata", "name") }.sort == %w[argocd-notifications-secret argocd-secret]
  abort "Argo CD 기본 Secret과 비어 있는 Notifications Secret만 생성해야 합니다."
end
secrets.each do |item|
  unless (item["data"] || {}).empty? && (item["stringData"] || {}).empty?
    abort "Argo CD 런타임 Secret 데이터를 Manifest에 지정하면 안 됩니다."
  end
end
secret = secrets.find { |item| item.dig("metadata", "name") == "argocd-secret" }
unless secret.dig("metadata", "annotations", "argocd.argoproj.io/sync-options") == "Prune=false,Delete=false"
  abort "Argo CD 런타임 Secret 삭제 방지 설정이 필요합니다."
end

notifications_service_account = resources.find do |item|
  item["kind"] == "ServiceAccount" && item.dig("metadata", "name") == "argocd-notifications-controller"
end
expected_notifications_role = "arn:aws:iam::686496667254:role/lookddak-#{environment}-argocd-notifications"
unless notifications_service_account&.dig("metadata", "annotations", "eks.amazonaws.com/role-arn") == expected_notifications_role
  abort "Notifications Controller ServiceAccount에는 Cloud에서 만든 전용 IRSA Role이 필요합니다."
end

notifications_deployment = resources.find do |item|
  item["kind"] == "Deployment" && item.dig("metadata", "name") == "argocd-notifications-controller"
end
notifications_env = notifications_deployment&.dig("spec", "template", "spec", "containers", 0, "env") || []
unless notifications_env.include?({ "name" => "AWS_DEFAULT_REGION", "value" => "ap-northeast-2" }) &&
       notifications_env.include?({ "name" => "TZ", "value" => "Asia/Seoul" })
  abort "Notifications Controller에는 AWS Region과 KST Timezone이 필요합니다."
end

notifications = resources.find do |item|
  item["kind"] == "ConfigMap" && item.dig("metadata", "name") == "argocd-notifications-cm"
end&.fetch("data", {})
abort "Argo CD Notifications ConfigMap이 필요합니다." unless notifications

service = YAML.safe_load(notifications.fetch("service.awssqs", "")) || {}
unless service == { "queue" => "lookddak-alert-queue", "region" => "ap-northeast-2" }
  abort "Notifications는 기존 중앙 Alert Queue만 사용해야 합니다."
end

template = notifications.fetch("template.lookddak-deploy-failed", "")
unless template.include?('"source": "custom.argocd"') &&
       template.include?('"sourceActionsUrl"') &&
       template.include?('"digest"')
  abort "실패 Template에는 Cloud Lambda 형식과 원본 배포 추적 정보가 필요합니다."
end

trigger = notifications.fetch("trigger.on-deploy-failed", "")
unless trigger.include?("app.status.operationState.phase in ['Error', 'Failed']") &&
       trigger.include?("app.status.health.status == 'Degraded'") &&
       trigger.include?("app.status.sync.status == 'Unknown'") &&
       trigger.include?("oncePer:") &&
       !notifications.keys.any? { |key| key.match?(/succeeded|deployed/) }
  abort "Notifications는 실패 조건만 revision 단위로 알리고 성공 Trigger를 만들지 않아야 합니다."
end
abort "Argo CD Ingress·Gateway·NetworkPolicy는 생성하지 않습니다." if resources.any? { |item| %w[Ingress Gateway NetworkPolicy].include?(item["kind"]) }
routes = resources.select { |item| item["kind"] == "HTTPRoute" }
expected_parent = { "group" => "gateway.networking.k8s.io", "kind" => "Gateway", "name" => "lookddak-gateway", "namespace" => "istio-ingress", "sectionName" => "https-argocd" }
unless routes.length == 1 &&
       routes[0].dig("spec", "parentRefs") == [expected_parent] &&
       routes[0].dig("spec", "hostnames") == [environment == "dev" ? "argocd.dev.lookddak.com" : "argocd.lookddak.com"] &&
       routes[0].dig("spec", "rules").flat_map { |rule| rule["backendRefs"] } == [{ "name" => "argocd-server", "port" => 80 }]
  abort "Argo CD HTTPRoute는 공용 Gateway https-argocd Listener에서 argocd-server:80으로만 연결해야 합니다."
end
params = resources.find { |item| item["kind"] == "ConfigMap" && item.dig("metadata", "name") == "argocd-cmd-params-cm" }
abort "Gateway에서 TLS를 종료하므로 server.insecure가 필요합니다." unless params&.dig("data", "server.insecure") == "true"
puts "Argo CD #{environment} 설치 검증 완료: 실행 구성요소 6개·Hook 1개 System 배치, SQS 실패 알림·IRSA, CRD 3개·런타임 Secret 보호, HTTPRoute 1개"
