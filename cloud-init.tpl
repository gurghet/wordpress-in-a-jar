#cloud-config
package_update: true
package_upgrade: true

runcmd:
  - export GITHUB_TOKEN=${github_token}
  - export HOME=/root
  - export XDG_CONFIG_HOME=/root/.config
  - curl -sfL https://get.k3s.io | sh -
  - export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  - until nc -z localhost 6443; do sleep 1; done
  - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  - curl -s https://fluxcd.io/install.sh | sudo bash
  - kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml --validate=false
  - flux bootstrap github --owner=gurghet --repository=wordpress-in-a-jar --branch=master --path=./flux/manifests