---
# ── Prometheus Alert Rules for order-service ─────────────────────────────────
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: order-service-alerts
  namespace: monitoring
  labels:
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
    - name: order-service.rules
      rules:

        # High error rate
        - alert: OrderServiceHighErrorRate
          expr: |
            rate(http_server_requests_seconds_count{
              application="order-service",
              status=~"5.."
            }[5m]) > 0.05
          for: 2m
          labels:
            severity: critical
            team: backend
          annotations:
            summary: "High error rate on order-service"
            description: "Error rate is {{ $value | humanizePercentage }} over last 5 minutes"

        # High P99 latency
        - alert: OrderServiceHighLatency
          expr: |
            histogram_quantile(0.99,
              rate(http_server_requests_seconds_bucket{
                application="order-service"
              }[5m])
            ) > 2
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "P99 latency > 2s on order-service"
            description: "P99 = {{ $value }}s"

        # Pod crash-looping
        - alert: OrderServicePodCrashLooping
          expr: |
            increase(kube_pod_container_status_restarts_total{
              namespace="production",
              pod=~"order-service.*"
            }[15m]) > 3
          for: 0m
          labels:
            severity: critical
          annotations:
            summary: "order-service pod is crash-looping"

        # Low replica count
        - alert: OrderServiceLowReplicas
          expr: |
            kube_deployment_status_replicas_ready{
              deployment="order-service",
              namespace="production"
            } < 2
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "order-service has fewer than 2 ready replicas"
