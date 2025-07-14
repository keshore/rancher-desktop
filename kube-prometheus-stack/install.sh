# helm --kube-context rancher-desktop upgrade --install \
# kube-prometheus kube-prometheus-stack \
# --repo https://prometheus-community.github.io/helm-charts \
# --namespace monitoring \
# --create-namespace \
# --set grafana.ingress.enabled=true \
# --set grafana.ingress.hosts[0]=grafana.localhost \
# --set grafana.ingress.ingressClassName=nginx \
# --set prometheus.prometheusSpec.maximumStartupDurationSeconds=60 \
# --set thanosRuler.enabled=true \
# --set thanosRuler.objectStorageConfig.type=FILESYSTEM \
# --set thanosRuler.objectStorageConfig.config.directory=/data/thanos \
# --set thanosRuler.thanosRulerSpec.queryEndpoints[0]=kube-prometheus-kube-prome-prometheus.monitoring.svc.cluster.local:9090 \
# --set kubelet.serviceMonitor.cAdvisor=false \
# --set alertmanager.enabled=false

kubectl --context rancher-desktop -n monitoring apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
    labels:
      app: cadvisor
    name: cadvisor
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  annotations:
    seccomp.security.alpha.kubernetes.io/pod: 'docker/default'
  labels:
    app: cadvisor
  name: cadvisor
spec:
  selector:
    matchLabels:
      app: cadvisor
      name: cadvisor
  template:
    metadata:
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
      labels:
        app: cadvisor
        name: cadvisor
    spec:
      automountServiceAccountToken: false
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
            - mountPath: /var/run
              name: var-run
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
      priorityClassName: system-node-critical
      terminationGracePeriodSeconds: 30
      serviceAccountName: cadvisor
      tolerations:
        - key: node.role.kubernetes.io/control-plane
          value: "true"
          effect: NoSchedule
        - key: node-role.kubernetes.io/etcd
          value: "true"
          effect: NoExecute
      volumes:
        - name: rootfs
          hostPath:
            path: /
        - name: var-run
          hostPath:
            path: /var/run
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
  labels:
    app: cadvisor
    release: kube-prometheus
spec:
  endpoints:
    - metricRelabelings:
        - sourceLabels:
            - container_label_io_kubernetes_pod_name
          targetLabel: pod
        - sourceLabels:
            - container_label_io_kubernetes_container_name
          targetLabel: container
        - sourceLabels:
            - container_label_io_kubernetes_pod_namespace
          targetLabel: namespace
        - action: labeldrop
          regex: container_label_io_kubernetes_pod_name
        - action: labeldrop
          regex: container_label_io_kubernetes_container_name
        - action: labeldrop
          regex: container_label_io_kubernetes_pod_namespace
      port: cadvisor
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
  selector:
    matchLabels:
      app: cadvisor
EOF
