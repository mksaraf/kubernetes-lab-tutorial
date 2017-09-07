# Troubleshooting
Changing TLS certificates on the apiserver, you'll need to refresh the service accounts as they contain invalid tokens.

    kubectl delete serviceaccount default
    kubectl delete serviceaccount --namespace=kube-system default
# Logs
Check service logs by 

    journalctl -xeu kube-apiserver
    journalctl -xeu kube-controller-manager
    journalctl -xeu kube-scheduler
    journalctl -xeu kubelet
    journalctl -xeu kube-proxy
