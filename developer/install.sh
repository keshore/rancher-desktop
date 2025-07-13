kubectl --context rancher-desktop apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app: developer
  name: developer
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: developer
  template:
    metadata:
      labels:
        app: developer
    spec:
      serviceAccountName: developer
      containers:
        - image: developer  # Ensure this image is correct and accessible
          imagePullPolicy: IfNotPresent
          name: developer
          command:
            - bash
            - -c
          args:
            - |
              cat /etc/profile.d/* > ~/.bash_profile
              echo "source \$HOME/.bash_profile" >> \$HOME/.bashrc
              cat >> \$HOME/.bash_profile <<-EOF
              function parse_git_branch() {
                git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
              }
              export PS1='\n\[\e]0;[\$(date "+%Y%m%d %H:%M:%S")] \u@\h: \w\a\]\${debian_chroot:+(\$debian_chroot)}\[\033[0;32m\][\$(date "+%Y%m%d %H:%M:%S")]\[\033[0;31m\] \u@\h\[\033[01;34m\]:\[\033[01;34m\]\w\[\033[00m\] \$(parse_git_branch)\n --> '
              cd \$HOME
              EOF
              source \$HOME/.bash_profile
              ln -s /host/.m2 ~/.m2
              ln -s /host/src ~/src
              while true; do
                echo "Developer container is running"
                sleep 5
              done
          volumeMounts:
            - name: host
              mountPath: /host
            - name: docker-socket
              mountPath: /var/run/docker.sock
      volumes:
        - name: host
          hostPath:
            path: $HOME
        - name: docker-socket
          hostPath:
            path: /var/run/docker.sock
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: developer
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: developer  # Ensure the ClusterRole "developer" exists
subjects:
  - kind: ServiceAccount
    name: developer
    namespace: default
---
apiVersion: v1
kind: Service
metadata:
  name: developer
  namespace: default
spec:
  ports:
    - name: http
      port: 3000
      protocol: TCP
      targetPort: 3000
  selector:
    app: developer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: developer
  namespace: default
spec:
  ingressClassName: nginx  # Ensure NGINX Ingress controller is installed
  rules:
    - host: developer.local  # Ensure DNS/hosts entry for developer.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: developer
                port:
                  number: 3000
EOF
