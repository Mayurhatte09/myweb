# EKS + Jenkins CI/CD — **myweb** project

> A complete step-by-step guide to deploy `https://github.com/Mayurhatte09/myweb.git` using Jenkins, Docker Hub, and an AWS EKS cluster (1 master, 2 nodes). This document contains commands, files, Jenkins job steps, IAM role notes, and troubleshooting tips.

---

## Table of contents

1. [Project overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Repository files you will use](#repository-files-you-will-use)
4. [AWS: Console steps & IAM users/roles](#aws-console-steps--iam)
   - [Create IAM user (for Jenkins/admin)](#create-iam-user-for-jenkinsadmin)
   - [Create IAM roles for EKS control plane and EC2 worker nodes](#create-iam-roles-for-eks-and-ec2-workers)
5. [Create EC2 instance for Jenkins (Amazon Linux, t3.large)](#create-ec2-instance-for-jenkins)
   - [Install Java, Jenkins, Docker, Maven, kubectl](#install-java-jenkins-docker-maven-kubectl)
   - [Linux user changes for jenkins user](#linux-user-changes-for-jenkins-user)
6. [Dockerfile and building image (local / Jenkins)](#dockerfile-and-building-image)
7. [Jenkins pipeline (Jenkinsfile) and Jenkins job steps](#jenkins-pipeline-and-job-steps)
   - [Add Docker Hub credentials to Jenkins](#add-docker-hub-credentials-to-jenkins)
   - [Create Pipeline job and connect repository](#create-pipeline-job-and-connect-repository)
8. [Push image to Docker Hub & update Kubernetes deployment](#push-image-to-docker-hub--update-k8s)
9. [Create EKS cluster and node group (high-level)](#create-eks-cluster-and-node-group)
   - [Update kubeconfig (example command)](#update-kubeconfig-example)
10. [Kubernetes manifests (deployments.yaml)](#kubernetes-manifests-deploymentsyaml)
11. [Validation & troubleshooting](#validation--troubleshooting)
12. [Cleanup](#cleanup)

---

## Project overview

This project automates building and deploying a Java webapp (`myweb.war`) into Tomcat on Kubernetes managed by AWS EKS. Jenkins will:

- Checkout code from GitHub (`myweb`)
- Run `mvn package` to produce `target/myweb*.war`
- Build a Docker image (based on `tomcat:9.0.109`) that copies the WAR into Tomcat webapps
- Push the image to Docker Hub (`mayrhatte09/myimage:v<build-number>`)
- Update the `deployments.yaml` (your repo stores it as `deployments.yaml`) with the new image tag and apply it to the cluster

Monitoring stack included in `deployments.yaml`: Prometheus + Grafana (NodePort services for quick testing).

---

## Prerequisites

- AWS account with permissions to create IAM users/roles, EC2, EKS, VPC, CloudFormation (if using `eksctl`), and related resources.
- Docker Hub account `mayrhatte09` (you already used this name in the Jenkinsfile).
- GitHub repository `https://github.com/Mayurhatte09/myweb.git` with a working Maven project producing a `.war`.
- Local or EC2 machine (we'll use an EC2 instance as Jenkins server) with internet access.
- `kubectl` binary accessible to the Jenkins user and AWS CLI configured with credentials that can access the EKS cluster.

---

## Repository files you will use

Below are the canonical files (use the exact content in your repo). Replace the placeholders only where noted.

### Dockerfile (use this exact content in repo root)

```dockerfile
FROM tomcat:9.0.109

COPY target/myweb*.war /usr/local/tomcat/webapps/myweb.war
```

> Keep this Dockerfile unchanged (as you requested).

### deployments.yaml (use the file you posted; include it in repo root)

*(Your file content — keep in repo as `deployments.yaml`)*

```yaml
# 1. My Web App Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mywebdeployment
  labels:
    app: myweb
spec:
  replicas: 4
  selector:
    matchLabels:
      app: myweb
  template:
    metadata:
      labels:
        app: myweb
    spec:
      containers:
      - name: myweb
        image: mayrhatte09/myimage:v1
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: myweb-service
spec:
  selector:
    app: myweb
  ports:
    - port: 8080
      targetPort: 8080
  type: NodePort

# 2. Prometheus Deployment
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus
        ports:
        - containerPort: 9090
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
spec:
  selector:
    app: prometheus
  ports:
    - port: 9090
      targetPort: 9090
  type: NodePort

# 3. Grafana Deployment
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana
        ports:
        - containerPort: 3000
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
spec:
  selector:
    app: grafana
  ports:
    - port: 3000
      targetPort: 3000
  type: NodePort
```

> Note: `image: mayrhatte09/myimage:v1` will be replaced by the Jenkins pipeline with the actual `v<BUILD_NUMBER>` tag.

---

## AWS: Console steps & IAM

### Create IAM user (for Jenkins/admin)

1. Sign in to AWS Console.
2. Go to **IAM** → **Users** → **Add user**.
   - Username: `jenkins` (or `ci-jenkins`) — your choice.
   - Access type: check **Programmatic access** and **AWS Management Console access** if you want console login.
   - For console password, choose auto-generated or custom.
3. Attach policies: you can attach a managed policy like `AdministratorAccess` for quick setup (not recommended for prod). For least privilege, attach policies needed by Jenkins to manage EKS and EC2, e.g. `AmazonEKSFullAccess`, `AmazonEC2FullAccess`, `AmazonS3FullAccess` (if you push artifacts to S3), `IAMReadOnlyAccess` (or more restricted as needed).
4. Finish and **Save**. Download the `Access key ID` and `Secret access key` (you will `aws configure` on the Jenkins EC2 instance using these).

> **Important**: For production, use a more restrictive set of permissions and use instance profiles for in-cluster actions where possible.

### Create IAM roles for EKS and EC2 worker nodes

You asked for two roles:

1. **Role for EKS master node (use case: EKS - eks cluster)**
   - In the console go to **IAM** → **Roles** → **Create role**.
   - Trusted entity: **EKS** (if using EKS-managed control plane integrations) or **EKS - Cluster** option in console.
   - Attach required managed policies for the control plane (the console sets these when enabling EKS); typically EKS control plane is AWS-managed, so this role is used when needed by tooling.

2. **Role for EC2 worker nodes (use case: EC2)**
   - Create role, trusted entity **EC2**.
   - Attach the following policies you specified (attach exact names):
     - `AmazonEKS_CNI_Policy` (Amazon EKS CNI Policy) — note exact managed policy name in console may differ; attach the `AmazonEKS_CNI_Policy` or the `AmazonEKS_CNI_Policy` CloudFormation-managed policy.
     - `AmazonEC2ContainerRegistryReadOnly` (gives nodes pull access to ECR if needed)
     - `AmazonEKSWorkerNodePolicy` (worker node policy)
   - Give the role a name like `eks-worker-role`.

> If you create nodes with `eksctl` or the EKS console, it will create and attach the correct IAM role automatically if you choose the managed nodegroup option. For self-managed nodes, attach this role to the EC2 instances.

---

## Create EC2 instance for Jenkins

Use **Amazon Linux 2** t3.large, 30 GiB root volume.

Console quick steps:
- EC2 → Launch Instance → Amazon Linux 2 AMI (x86_64) → Instance type `t3.large` → Configure storage: 30 GiB root → Security group: open ports 22 (SSH), 8080 (Jenkins default), 50000 (Jenkins agent) and Docker/other ports as needed (only for test; restrict in prod).
- Key pair: create or use existing for SSH.

SSH into instance (from your workstation):

```bash
ssh -i ~/keys/mykey.pem ec2-user@<EC2_PUBLIC_IP>
```

### Install Java, Jenkins, Docker, Maven, kubectl

Run these commands as `ec2-user` (use sudo where needed). These commands are for Amazon Linux 2.

```bash
# update
sudo yum update -y

# 1) Install Docker
sudo amazon-linux-extras install docker -y
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# 2) Install Java (OpenJDK 11) for Jenkins & Maven
sudo yum install -y java-11-amazon-corretto-headless

# 3) Install Jenkins (official repo)
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
sudo yum install -y jenkins
sudo systemctl enable --now jenkins

# 4) Install Maven
sudo yum install -y maven

# 5) Install kubectl (stable binary)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# ensure /usr/local/bin is in PATH for jenkins user and system

# 6) (Optional) Install awscli v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# show versions
java -version
mvn -v
docker --version
kubectl version --client
jenkins --version   # may require sudo systemctl status jenkins to check
```

> After adding `ec2-user` to `docker` group you may need to `newgrp docker` or relogin.

### Create Jenkins user shell / permission changes (your commands adapted)

You listed a chain of commands — here is a clean version to set Jenkins user's shell and give Docker access to Jenkins service user:

```bash
# Add 'jenkins' to docker group (so Jenkins can run docker commands)
sudo usermod -aG docker jenkins

# change jenkins shell to bash so 'su - jenkins' works nicely
sudo usermod -s /bin/bash jenkins

# switch to jenkins user (after relogin or restart service)
sudo su - jenkins

# verify
grep jenkins /etc/passwd
```

If you want to allow `jenkins` to run `docker` without sudo, confirm `jenkins` is in docker group and restart Jenkins service:

```bash
sudo systemctl restart jenkins
```

---

## Dockerfile and building image

Your Dockerfile (already shown above) will be built by Jenkins after `mvn package` creates `target/myweb*.war`.

Local build example (for testing):

```bash
# from repo root where Dockerfile is
docker build -t mayrhatte09/myimage:v1 .
# test run
docker run --rm -p 8080:8080 mayrhatte09/myimage:v1
```

Push manual steps (if testing locally before Jenkins):

```bash
docker login -u mayrhatte09
docker tag mayrhatte09/myimage:v1 mayrhatte09/myimage:v1
docker push mayrhatte09/myimage:v1
```

---

## Jenkins pipeline and job steps

Your `Jenkinsfile` (you provided) looks good. Add it to repository root. I include a slightly hardened shell quoting version below (safe for Jenkins `sh` steps):

```groovy
pipeline {
    agent any

    tools { maven 'Apache Maven 3.8.4' }

    environment {
        DOCKER_HUB_USER = 'mayrhatte09'
        IMAGE_NAME = 'myimage'
    }

    stages {
        stage('Git Checkout') { steps { git url: 'https://github.com/Mayurhatte09/myweb.git', branch: 'main' } }

        stage('Maven Build') { steps { sh 'mvn clean package -DskipTests=false' } }

        stage('Docker Build') {
            steps { sh "docker build -t ${IMAGE_NAME}:v${BUILD_NUMBER} ." }
        }

        stage('Docker Login & Push') {
            steps {
                withCredentials([string(credentialsId: 'dockerhub-pass', variable: 'DOCKER_HUB_PASS')]) {
                    sh '''
                      echo "$DOCKER_HUB_PASS" | docker login -u "$DOCKER_HUB_USER" --password-stdin
                      docker tag ${IMAGE_NAME}:v${BUILD_NUMBER} ${DOCKER_HUB_USER}/${IMAGE_NAME}:v${BUILD_NUMBER}
                      docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:v${BUILD_NUMBER}
                    '''
                }
            }
        }

        stage('Update Deployment File') {
            steps {
                sh '''
                  sed -i "s|${DOCKER_HUB_USER}/${IMAGE_NAME}:v[0-9]*|${DOCKER_HUB_USER}/${IMAGE_NAME}:v${BUILD_NUMBER}|g" deployments.yaml
                  echo 'Updated deployment image to: ${DOCKER_HUB_USER}/${IMAGE_NAME}:v${BUILD_NUMBER}'
                '''
            }
        }

        stage('Kubernetes Deployment') {
            steps {
                sh '''
                  kubectl apply -f deployments.yaml
                  kubectl rollout restart deployment mywebdeployment || true
                  kubectl get pods -o wide
                '''
            }
        }
    }
}
```

> The pipeline expects a Jenkins credential with id `dockerhub-pass` that stores your Docker Hub password (or a Docker Hub token) as a **Secret text** in Jenkins credentials store. The username is provided by `DOCKER_HUB_USER` in environment.

### Add Docker Hub credentials to Jenkins

1. Open Jenkins UI: `http://<EC2_PUBLIC_IP>:8080` (unlock Jenkins using initial admin password at `/var/lib/jenkins/secrets/initialAdminPassword`).
2. Manage Jenkins → Manage Credentials → (global) → Add Credentials.
   - Kind: **Secret text**
   - Secret: `<your Docker Hub password or token>`
   - ID: `dockerhub-pass`
   - Description: `DockerHub password for mayrhatte09`

> Alternatively use **Username with password** credential kind and then adapt the pipeline to access both username and password via `usernamePassword` credentials block.

### Create Pipeline job and connect repository

1. New Item → Pipeline → give it a name like `myweb-cicd`.
2. Under **Pipeline** definition, choose **Pipeline script from SCM** → Git.
   - Repository URL: `https://github.com/Mayurhatte09/myweb.git`
   - Branch: `main`
   - Script Path: `Jenkinsfile`
3. Save and click **Build Now**.

**If Jenkins runs Docker commands**: run Jenkins as a user that can access Docker (we added `jenkins` to `docker` group). If you see permission issues, confirm group membership and restart Jenkins.

---

## Push image to Docker Hub & update Kubernetes deployment

What the pipeline does:

- After successful build, it tags image as `mayrhatte09/myimage:v<BUILD_NUMBER>` and pushes to Docker Hub.
- It updates `deployments.yaml` to replace the image tag with latest, then runs `kubectl apply -f deployments.yaml` and `kubectl rollout restart` for `mywebdeployment`.

**Important:** Jenkins needs `kubectl` configured to talk to your EKS cluster. We'll cover kubeconfig below.

---

## Create EKS cluster and node group (high-level)

You can create the cluster using the **EKS Console** or `eksctl` (CLI). For a simple setup:

**Using eksctl (recommended for quick setup):**

```bash
# install eksctl locally or on EC2
eksctl create cluster \
  --name moster-node \
  --region ap-southeast-1 \
  --nodegroup-name mynodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 3 \
  --managed
```

This will create a cluster named `moster-node` in `ap-southeast-1` with 2 worker nodes (managed nodegroup). `eksctl` will create IAM roles and node IAM profiles for you — strongly recommended.

**Using AWS Console:**
- EKS → Create cluster → give `moster-node` name, VPC settings (default or custom), choose node group → create node group with 2 nodes, and attach the worker role you created earlier.

> If you follow console steps, attach the `eks-worker-role` to EC2 worker instances.

### Update kubeconfig (example command)

On the Jenkins EC2 instance (or wherever Jenkins runs `kubectl`), configure access to the cluster:

```bash
# region ap-southeast-1, cluster name 'moster-node'
aws eks update-kubeconfig --region ap-southeast-1 --name moster-node

# verify
kubectl get nodes
kubectl get pods -A
```

Add this command in your Jenkins job pre-build steps if Jenkins does not already have kubeconfig or if you rotate credentials. Alternatively store the kubeconfig at `/var/lib/jenkins/.kube/config` owned by `jenkins` user so pipeline kubectl commands run without extra steps.

**Tip**: If you created cluster using `eksctl` from the Jenkins host, kubeconfig is automatically created for that user.

---

## Kubernetes manifests (deployments.yaml)

You already provided the `deployments.yaml`. Keep it in repo root and let the pipeline sed-replace the image tag. The pipeline expects the `image` field to match `mayrhatte09/myimage:v<digits>` so sed can find and replace it.

If your image tag format differs, update the sed pattern accordingly.

---

## Validation & troubleshooting

### Useful commands

```bash
# on Jenkins host (or local with kubeconfig)
kubectl get nodes
kubectl get pods -n default
kubectl describe pod <pod-name>
kubectl logs <pod-name> -c myweb

# Check image exists on Docker Hub (manual check)
docker pull mayrhatte09/myimage:v<build_number>

# Check Jenkins logs
sudo journalctl -u jenkins -f

# Jenkins user docker permissions
sudo su - jenkins
docker ps
```

### Common issues & fixes

- **Jenkins cannot run docker**: ensure `jenkins` in `docker` group and restart Jenkins.
- **kubectl permission denied**: place kubeconfig at `/var/lib/jenkins/.kube/config` with correct ownership `jenkins:jenkins` and mode `600`.

```bash
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo chmod 600 /var/lib/jenkins/.kube/config
```

- **Image not found on Docker Hub**: ensure pipeline pushed to `mayrhatte09/myimage:v<build_number>` and image is public or nodes can authenticate to Docker Hub. If private, either make image public or configure imagePullSecrets on the deployment and create a Kubernetes secret with Docker credentials.

Create imagePullSecret example:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<your-username> \
  --docker-password=<your-password-or-token> \
  --docker-email=you@example.com

# then add to deployment spec:
# spec:
#   imagePullSecrets:
#   - name: regcred
```

---

## Cleanup

To avoid charges when done:

- Delete EKS cluster (Console / eksctl delete cluster --name moster-node)
- Terminate EC2 instances (Jenkins host)
- Delete ECR / Docker images if not needed
- Remove IAM users/roles you created

---

## Appendix: Quick commands summary

```bash
# on Jenkins EC2 host
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo systemctl enable --now docker
sudo yum install -y java-11-amazon-corretto-headless maven
# install jenkins repo
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
sudo yum install -y jenkins
sudo systemctl enable --now jenkins

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# aws configure (use Jenkins user or ec2-user depending where you run aws cli)
aws configure

# update kubeconfig
aws eks update-kubeconfig --region ap-southeast-1 --name moster-node

# eksctl example (create cluster)
eksctl create cluster --name moster-node --region ap-southeast-1 --nodegroup-name mynodes --nodes 2 --managed
```

---

*Document created for: Mayur Hatte — `myweb` CI/CD to EKS*

