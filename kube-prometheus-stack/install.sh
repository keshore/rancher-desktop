helm --kube-context rancher-desktop upgrade --install \
kube-prometheus kube-prometheus-stack \
--repo https://prometheus-community.github.io/helm-charts \
--namespace monitoring \
--create-namespace \
--set grafana.ingress.enabled=true \
--set grafana.ingress.hosts[0]=grafana.localhost \
--set grafana.ingress.ingressClassName=nginx \
--set prometheus.prometheusSpec.maximumStartupDurationSeconds=60 \
--set thanosRuler.enabled=true \
--set thanosRuler.objectStorageConfig.type=FILESYSTEM \
--set thanosRuler.objectStorageConfig.config.directory=/data/thanos \
--set thanosRuler.thanosRulerSpec.queryEndpoints[0]=kube-prometheus-kube-prome-prometheus.monitoring.svc.cluster.local:9090 \
--set kubelet.serviceMonitor.cAdvisor=false \
--set alertmanager.enabled=false

kubectl --context rancher-desktop apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
    labels:
      app: cadvisor
    name: cadvisor
    namespace: monitoring
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app: cadvisor
  name: cadvisor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: cadvisor
  template:
    metadata:
      labels:
        app: cadvisor
    spec:
      containers:
        - image: gcr.io/cadvisor/cadvisor:v0.45.0
          imagePullPolicy: IfNotPresent
          name: cadvisor
          args:
            - --housekeeping_interval=10s
            - --max_housekeeping_interval=15s
            - --event_storage_event_limit=default=0
            - --event_storage_age_limit=default=0
            - --enable_metrics=app,cpu,disk,diskIO,memory,network,process
            - --docker_only
            - --store_container_labels=false
            - --whitelisted_container_labels=io.kubernetes.pod.name,io.kubernetes.pod.namespace,io.kubernetes.container.name
          ports:
            - containerPort: 8080
              protocol: TCP
              name: http
          volumeMounts:
            - mountPath: /rootfs
              name: rootfs
              readOnly: true
            - mountPath: /sys
              name: sys
              readOnly: true
            - mountPath: /var/lib/docker
              name: docker
              readOnly: true
            - mountPath: /dev/disk
              name: disk
              readOnly: true
      serviceAccountName: cadvisor
      volumes:
        - name: rootfs
          hostPath:
            path: /
        - name: sys
          hostPath:
            path: /sys
        - name: docker
          hostPath:
            path: /var/lib/docker
        - name: disk
          hostPath:
            path: /dev/disk
---
apiVersion: v1
kind: Service
metadata:
  name: cadvisor
  namespace: monitoring
  labels:
    app: cadvisor
spec:
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
      name: cadvisor
  selector:
    app: cadvisor
  type: NodePort
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cadvisor
  namespace: monitoring
  labels:
    app: cadvisor
    release: kube-prometheus
spec:
  selector:
    matchLabels:
      app: cadvisor
  endpoints:
    - port: cadvisor
      interval: 30s
      metricRelabelings:
        - sourceLabels:
            - container_label_io_kubernetes_pod_name
          targetLabel: pod
        - sourceLabels:
            - container_label_io_kubernetes_pod_namespace
          targetLabel: namespace
        - sourceLabels:
            - container_label_io_kubernetes_container_name
          targetLabel: container
        - action: labeldrop
          regex: (container_label_io_kubernetes_pod_name|container_label_io_kubernetes_pod_namespace|container_label_io_kubernetes_container_name)
      relabelings:
        - sourceLabels:
            - __meta_kubernetes_pod_node_name
          targetLabel: node
        - sourceLabels:
            - __metrics_path__
          targetLabel: metrics_path
          replacement: /metrics/cadvisor
        - sourceLabels:
            - job
          targetLabel: job
          replacement: kubelet
  namespaceSelector:
    matchNames:
      - monitoring
EOF
