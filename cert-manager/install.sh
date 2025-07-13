helm --kube-context rancher-desktop repo add jetstack https://charts.jetstack.io --force-update

helm --kube-context rancher-desktop install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.0 \
  --set crds.enabled=true

kubectl --context rancher-desktop apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
  namespace: default
spec:
  selfSigned: {}

---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: default
spec:
  commonName: my-selfsigned-cert.local
  dnsNames:
    - my-selfsigned-cert.local
  secretName: selfsigned-cert-tls
  issuerRef:
    name: selfsigned-issuer
    kind: Issuer
EOF
