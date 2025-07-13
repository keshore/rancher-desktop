helm --kube-context rancher-desktop upgrade --install \
    ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.extraArgs.enable-ssl-passthrough=""