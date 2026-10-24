# Example Voting App — DevOps Capstone

## 1. Project Overview

This project extends the Docker Example Voting App with container security improvements, automated CI/CD, Kubernetes deployment using Helm, and infrastructure provisioning using Terraform.

The application demonstrates a distributed system in which votes move through a queue to a worker, are stored in PostgreSQL, and are displayed by the results application.

### Application components

- **Vote:** Python web application for submitting a vote.
- **Redis:** Queue for incoming votes.
- **Worker:** .NET service that transfers votes from Redis to PostgreSQL.
- **PostgreSQL:** Database for persistent vote records.
- **Result:** Node.js web application that displays voting results.

### Application flow

`Vote → Redis → Worker → PostgreSQL → Result`

## 2. Repository Structure
## Architecture

![Architecture diagram](architecture.excalidraw.png)

Important project paths:

| Path | Purpose |
|---|---|
| `vote/` | Vote application and Docker configuration |
| `result/` | Results application and Docker configuration |
| `worker/` | Background worker and Docker configuration |
| `seed-data/` | Seed-data container |
| `docker-compose.yml` | Local multi-container application |
| `.github/workflows/ci-cd.yml` | GitHub Actions pipeline |
| `terraform/` | Terraform infrastructure configuration |
| `helm/voting-app/` | Helm chart and values |
| `architecture.excalidraw.png` | Architecture diagram |

## 3. Prerequisites

Install and configure the tools required for the phase you intend to run:

- Git
- Docker Engine and Docker Compose
- AWS CLI with authorized AWS credentials
- Terraform
- `kubectl`
- Helm
- GitHub CLI (`gh`), if you want to inspect workflow runs from the terminal

For Kubernetes deployment, you also need an accessible Amazon EKS cluster and appropriate AWS and Kubernetes permissions.

Check the relevant tool installations:

```bash
git --version
docker --version
docker compose version
terraform version
kubectl version --client
helm version
aws --version
```

## 4. Run the Application Locally

From the repository root, build and start the application:

```bash
docker compose up --build -d
```

Check container status:

```bash
docker compose ps
```

View logs when troubleshooting:

```bash
docker compose logs --tail=100
```

The local application is available at:

- Vote: `http://localhost:8080`
- Results: `http://localhost:8081`

Submit a vote and refresh the results page to verify the end-to-end flow.

Stop the local application:

```bash
docker compose down
```

This command stops and removes the Compose-managed containers and network. Review your Compose configuration and volumes before removing persistent data.

## 5. Containerization and Security

The application has Dockerfiles and `.dockerignore` files for the relevant services. Application containers are configured to run as non-root users where applicable.

The project also includes container image scanning in its CI/CD workflow.

When changing Dockerfiles or base images:

- Keep base images pinned to intentional versions or digests where appropriate.
- Avoid running application processes as root.
- Exclude unnecessary files from build contexts.
- Do not include passwords, tokens, or other secrets in images.
- Review image scan findings before publishing or deploying.

The automated workflow provides repeatable validation and image publication. A successful image scan does not guarantee that an image is free of all vulnerabilities.

## 6. CI/CD with GitHub Actions

The workflow is located at:

`.github/workflows/ci-cd.yml`

It validates the application, builds the required images, scans images with Trivy, and publishes SHA-tagged images to GitHub Container Registry (GHCR).

### Verified successful workflow run

- **Workflow:** Voting App CI
- **Branch:** `main`
- **Run ID:** `40076397685`
- **Commit:** `a97d0f4` — Update Helm chart to verified image SHA
- **Result:** All five jobs passed

The successful jobs were:

1. Test application
2. Build, scan, and publish the result image
3. Build, scan, and publish the vote image
4. Build, scan, and publish the worker image
5. Build, scan, and publish the seed-data image

[View the successful GitHub Actions run](https://github.com/StormyAyo/example-voting-app/actions/runs/40076397685)

The workflow output included non-fatal warnings about GitHub Actions Node.js runtime deprecation and the `ubuntu-latest` runner image migration. These warnings did not cause the recorded run to fail.

### Published application images

The application images are published to GHCR:

- `ghcr.io/stormyayo/example-voting-app-vote`
- `ghcr.io/stormyayo/example-voting-app-result`
- `ghcr.io/stormyayo/example-voting-app-worker`

The deployed application image tag verified during this deployment was:

`9b59ba8e5ee54951154d3f412a3a73baba29cb0e`

The workflow run above belongs to commit `a97d0f4`, while the deployed application images use the earlier SHA tag shown above. These are different references: the workflow commit identifies the source revision that ran through CI, and the image tag identifies the application image deployed by Helm.

For a future deployment, confirm that the selected SHA tag exists in GHCR before upgrading the Helm release.

## 7. Infrastructure as Code with Terraform

Terraform configuration is maintained in `terraform/`.

From the repository root:

```bash
cd terraform
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

Review the plan before applying infrastructure changes. Confirm the AWS account, region, cluster configuration, and estimated costs.

Only apply changes after reviewing and approving the plan:

```bash
terraform apply
```

To review a proposed teardown:

```bash
terraform plan -destroy
```

If you decide to remove the infrastructure, review the proposed actions and data-retention implications before running:

```bash
terraform destroy
```

**Important:** destroying infrastructure can interrupt the application and may affect persistent data. A successful `terraform validate` confirms that the configuration is valid; it does not independently prove that a new cluster can be recreated successfully.

## 8. Kubernetes Deployment with Helm

The Helm chart is located at:

`helm/voting-app/`

### Validate the chart

Run from the repository root:

```bash
helm lint helm/voting-app
```

Render the manifests locally:

```bash
helm template voting helm/voting-app \
  --namespace default \
  --values helm/voting-app/values.yaml
```

### Deploy or upgrade the application

```bash
helm upgrade --install voting helm/voting-app \
  --namespace default \
  --values helm/voting-app/values.yaml \
  --wait \
  --timeout 5m
```

### Check the release and Kubernetes resources

```bash
helm status voting --namespace default
helm history voting --namespace default
kubectl get deployments,pods,services,pvc --namespace default
```

Check the pods and wait for the application deployments to become available before performing the end-to-end test.

### Access the applications locally

Open two terminal sessions and keep each port-forward running.

Vote application:

```bash
kubectl port-forward service/voting-vote 8082:80
```

Open `http://localhost:8082`.

Results application, in a second terminal:

```bash
kubectl port-forward service/voting-result 8083:80
```

Open `http://localhost:8083`.

These commands require a working Kubernetes context and the corresponding services to exist in the `default` namespace.

## 9. PostgreSQL Persistent Storage

PostgreSQL uses the `voting-postgres-data` PersistentVolumeClaim.

The verified deployment used:

- **Claim:** `voting-postgres-data`
- **Capacity:** 2 GiB
- **StorageClass:** `ebs-csi-gp3`
- **Provisioner:** `ebs.csi.aws.com`
- **Observed state:** `Bound`

Check the claim:

```bash
kubectl get pvc voting-postgres-data --namespace default
kubectl get storageclass ebs-csi-gp3
```

The EBS CSI driver and the necessary AWS permissions must be configured for dynamic EBS volume provisioning.

**Data-retention warning:** do not delete the PostgreSQL PVC or its underlying volume if you need to preserve votes. Review the StorageClass reclaim policy, backup requirements, and recovery procedure before deleting storage or uninstalling the release.

## 10. Helm Rollback Validation

A controlled upgrade using an invalid image tag was tested. The upgrade failed, and the release was rolled back to a known-good revision. The application was subsequently checked to confirm that the deployments were available, the pods were running, and PostgreSQL storage remained bound.

### Inspect release history

Always inspect the actual revision numbers before rolling back:

```bash
helm history voting --namespace default
```

### Roll back to a known-good revision

Replace `<REVISION>` with the appropriate known-good revision shown in the history:

```bash
helm rollback voting <REVISION> \
  --namespace default \
  --wait \
  --timeout 5m
```

Verify the result:

```bash
helm status voting --namespace default
kubectl get deployments,pods,pvc --namespace default
```

Revision numbers change as upgrades and rollbacks are performed. Do not assume a fixed revision number will always be the correct target.

## 11. End-to-End Validation

The deployed application was tested by submitting votes through the vote interface and checking the results interface.

The recorded validation evidence included:

- Vote interface loaded successfully.
- Results interface loaded successfully.
- Worker logs showed votes being processed.
- Result application logs confirmed a database connection.
- Submitting a vote and refreshing the results interface showed the updated selection.
- All five application deployments were available after rollback.
- PostgreSQL persistent storage was bound.

To inspect application logs:

```bash
kubectl logs deployment/voting-worker --namespace default
kubectl logs deployment/voting-result --namespace default
kubectl logs deployment/voting-postgres --namespace default
```

If a deployment has multiple pods or logs are unavailable, inspect the pod names and events:

```bash
kubectl get pods --namespace default
kubectl get events --namespace default --sort-by=.lastTimestamp
```

The application permits one vote per client browser. Submitting a different selection from the same browser updates that client's vote rather than creating another independent voter.

## 12. Secrets and Operational Safety

- Do not commit passwords, access keys, tokens, or kubeconfig credentials.
- Use GitHub Actions secrets or an appropriate secret manager for CI/CD credentials.
- Kubernetes application secrets should be created and managed securely.
- Do not paste secret values into source control or public logs.
- Review image scan findings and update deprecated GitHub Actions when appropriate.
- Use image tags that can be traced to a specific source revision.
- Verify deployment health after upgrades and rollbacks.
- Review AWS costs and clean up resources that are no longer required.
- Confirm persistent-data backup and retention requirements before deleting storage.

## 13. Capstone Evidence and Links

- [Source repository](https://github.com/StormyAyo/example-voting-app)
- [Latest verified successful GitHub Actions run](https://github.com/StormyAyo/example-voting-app/actions/runs/40076397685)
- Helm chart: `helm/voting-app/`
- Terraform configuration: `terraform/`
- Architecture diagram: `architecture.excalidraw.png`

## 14. Project Limitations and Verification Notes

This project demonstrates containerization, CI/CD, infrastructure as code, Kubernetes deployment, persistent storage, and Helm rollback.

The validation results documented here reflect the commands and deployment checks performed during the project. A successful validation or workflow run should not be interpreted as proof of every possible failure mode, a fresh-cluster recreation, or complete security.

Before submitting, confirm that the committed README, Terraform configuration, Helm values, workflow file, and deployed image references are consistent with the final repository state.
