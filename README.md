So, I wanted my Wordpress website, but, being a software engineer, I didn't want to pay for it, not anything except the little more than the electricity needed to run a machine. Also, in the past I accidentally the whole website (more than once 🥲). To be clear, I did have the backup, but was to lazy to set up the whole system from scratch. Create the server, spin up the database, run the migration, and all that jazz.
I don't want this to happen ever again 😡!
So I set to myself the rule that whatever I build, even the most innocent Telegram bot to randomly choose the pizza for me (by the way why it doesn't have AI yet to understand my tastes?)

![My non-AI pizza bot](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/mku2eypvy6ty8vc9bujx.jpeg)

Whatever I build from now on will be IaC, so that if I accidentally again the whole cloud account, I would be able to recreate it with the push of a button (preferably Enter, after issuing the `terraform plan` command).

### The machines


![Hetzner thrifty prices](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/8o78adl2upuokqovwb73.png)

Hetzner is a thrifty hosting, I don't know what that means, let me check the dictionary... oh makes sense. Well you can have the cheapest server for just a few euros a month, I always choose ARM because it seems cooler (figuratively and literally). But Intel has the same prices more or less.

This is the bulk of the expense for our new Wordpress website. Good.

From the hetzner cloud get your read/write API token.

### The machines, as code

We’re going to use Terraform to automate everything. Terraform is an open-source IaC tool that lets you define and provision your infrastructure with code. No more manual setup or hoping you didn’t screw up a step. With Terraform, you get consistency, fewer errors, and version control. Plus, if you need to wipe everything and start fresh, it’s just a couple of commands away. It’s the perfect tool to make sure your infrastructure is always up and running exactly how you want it.

We are going to use some free cloud services, but none of them are necessary, we'll use them for their power to streamline workflow:
I would highly suggest to get a Terraform Cloud account, the free plan can manage 500 resources which is plenty.
Get an account at Doppler.com, it's basically a vault and will be useful to let the secret survive a total wipeout event. It also has a free tier. Get the API token for that as well (read only is fine for now).

Once you have these two create a new folder for this project and make it a git repository. For simplicity I'm going to assume we have a GitHub repo called `wordpress-in-a-jar` (in theory could be GitLab, BitBucket or even hosted on-premise). Yes, get an API token for that too, we'll need that to read/write the repository content.

Create a `main.tf` with the following:

```terraform
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

variable "hcloud_token" {
  type = string
}

variable "github_token" {
  type = string
}

resource "hcloud_server" "master_node" {
  name        = "geppetto"
  image       = "ubuntu-20.04"
  server_type = "cax11"
  location    = "fsn1"
  user_data   = templatefile("${path.module}/cloud-init.tpl", {
    github_token  = var.github_token
  })

  ssh_keys = [data.hcloud_ssh_key.gaia_key.id]
}

output "ip_address" {
  value = hcloud_server.master_node.ipv4_address
}

resource "hcloud_ssh_key" "gaia_key" {
  name        = "Public key of my MacBook Pro (Gaia)"
  public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDUAl/qrUV1Nkcd7fPbYAahOAg7p4Nn5+Gkv5Y1lQ/Hm7DqSJki9mmxhtuB/HHV3pZuriAzVJKpee8q8p55EnWhv9xw04oHBXYuJYzkU0kNMiZGMgh/Z8BNkY7QBqitDLOeCNk8gKpKYY0kbINvUaWUNy/JQdmLUu9erCzbkkC0k3KLTlVRr6ZyKuJ6yHX9zYHDJRw9iO+SKA7V/fFVBZtxfYXNN0GaDw6+33z7A7pxbt4wlCuFir2AYTUcU6E2jwrtpq9gwJ0dXiiOW5H/RRGJ1D3VDIcag+Zy7p54K3fH2KOgjujbPq6SS8zJ8/GE+iHCCVxhLnXLin66rRUOIbYVzxPtryX+f4fAxfxTWKLMNWWIVFa11/FOJ792j9MIuYvV/dn3nICsBSQToGQ94A7LoN6W0j4INViHbkzEZVaXQth2urFQ/1NmJGnQkbRR8/XU4ej06WUtie9oGjNY2SXOKVahjBWoybunbtKuv4gtz/XEQKjQDU4T1qXJ6k11jEM= gurghet@Gaia.local"
}
```

That's my actual public key of my laptop, you have to put your own key there, otherwise I'll be able to access your machine :D

![Here is a meme for the people who didn't read the above paragraph](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/944v9cwtxylh910ieso4.png)

#### Cloud-init

The line referring to the `cloud-init.tpl` is calling built-in facility (in most server operating systems) for initializing and configuring cloud instances. It's very complicated how it works, has many modules and functionalities but we'll only use a few.

```yaml
#cloud-config
runcmd:
  - export GITHUB_TOKEN=${github_token}
  - export HOME=/root
  - export XDG_CONFIG_HOME=/root/.config
  - curl -sfL https://get.k3s.io | sh - # install k8s
  - export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  - until nc -z localhost 6443; do sleep 1; done # wait until k8s is live
  - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash # get helm
  - curl -s https://fluxcd.io/install.sh | sudo bash
  - kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml --validate=false
  - flux bootstrap github --owner=gurghet --repository=wordpress-in-a-jar --branch=master --path=./flux/manifests
```

In the last command we are provisioning the node with flux CD, which will watch every our step in the git repository and reconciliate until the cluster looks exactly like our code.

Similarly here, you should use your github handle instead of `gurghet` and possibly other parameters accordingly. They should all correspond to a real GitHub repository that you created and uploaded, with the above two files inside basically.

## Doing the stuff

Now that your repository is accessible on GitHub, you should actually tell terraform to create all this on Hetzner. You should use the following commands:

```
terraform init
terraform apply -var 'hcloud_token=<your hetzner token>' -var 'github_token=<your github token>'
```

The firt command prepares the terraform environment and initializes the state, the second actually executes the code we wrote. We are manually passing the secrets now, but we will move them away later. We want a push-button experience, no manual secret management required.

The plan will spit out the ip address of your new master node Geppetto, you should then be able to log in with ssh:

```
ssh root@<Geppetto's ip>
```

Once inside you can check that the provisioning was succcessful by tailing the logs, I got:

```
root@geppetto:~# tail -f /var/log/cloud-init-output.log
✔ GitRepository reconciled successfully
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✔ Kustomization reconciled successfully
► confirming components are healthy
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ all components are healthy
Cloud-init v. 24.1.3-0ubuntu1~20.04.1 finished at Sat, 15 Jun 2024 21:24:35 +0000. Datasource DataSourceHetzner.  Up 113.81 seconds
```

If this worked you should find a new commit to your flux. This initial commit contains all the necessary files for Flux to manage your cluster state.

Congratulations! You have a master node waiting for your commands. But let's say you want to call it a day and continue building this tomorrow. You don't need to keep your machine running and spending all your money. You can use `terraform destroy` and then, tomorrow after a coffee, `terraform apply` like above to instantly recreate your cluster.

![Saving money you would have not spent if you didn't read this article](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/aq5xainkaq70ny1q8t1z.png)

## Spinning up the wordpress

Everything you write in the `manifests` folder will become true. So let's create a new folder for our Wordpress website: we'll call it "bot-buffet" an all-you-can-click Telegram bot marketplace. We'll use the excellent bitnami helm. This is how the directory structure is looking now:

![dir tree](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/fskuxqbadkbxp27w0j7b.png)

We are going to need 4 charts here:

1. Bitnami helm repository
2. A namespace for `bot-buffet`
3. *The HelmRelease itself with Wordpress*
4. An Ingress to instruct Traefik to route to it

I said charts but let's actually but everything inside `wordpress-helm.yaml` because doing like this increase coesion and makes it easier to read the code.

The first 2 are straightforward:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: bitnami
  namespace: flux-system
spec:
  interval: 10m
  url: https://charts.bitnami.com/bitnami
---
apiVersion: v1
kind: Namespace
metadata:
  name: bot-buffet
---
```
The bitnami chart needs some value, in particular we can choose name and email, but importantly we must disable the built-in loadbalancer (we don't want to spend money, remember?) and let's instead use Traefik.

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: bot-buffet-wordpress
  namespace: bot-buffet
spec:
  interval: 5m
  chart:
    spec:
      chart: wordpress
      version: "22.4.5"
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
  values:
    wordpressUsername: "gurghet"
    wordpressEmail: "gurghet@proton.me"
    wordpressBlogName: "Bot Buffet"
    service:
      type: ClusterIP
    ingress:
      enabled: true
      ingressClassName: "traefik"
---
```
Perfect! The last think will be the Ingress entry to tell Traefik to actually send in all the customers that come from port 80.

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bot-buffet-wordpress-ingress
  namespace: bot-buffet
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: bot-buffet-wordpress
            port:
              name: http
---
```

The service `bot-buffet-wordpress` is hardcoded because this is what the helm chart above will create.

At this point you just need to commit and push to github this new file. The flux will pick it up and magically create your Wordpress! Try it by pointing your browser to the ip of the machine.


![Our new Wordpress website](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/njrt9ym5h4hu4dz03ooq.png)

Of course there is a bunch of things that we still need to do: where is my domain with TLS certificate? Where are all the password to access my Wordpress and Database? How do I debug if something goes wrong? Where are my Telegram bots? I'm going to tell you next time.

![chuck norris once kicked a server to build a Wordpress site](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/hw0z01231qvu2h5075qw.png)
