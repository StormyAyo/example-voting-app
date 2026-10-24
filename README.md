# Example Voting App

A simple distributed application running across multiple Docker containers.

## Getting started

Download [Docker Desktop](https://www.docker.com/products/docker-desktop) for Mac or Windows. [Docker Compose](https://docs.docker.com/compose) will be automatically installed. On Linux, make sure you have the latest version of [Compose](https://docs.docker.com/compose/install/).

This solution uses Python, Node.js, .NET, with Redis for messaging and Postgres for storage.

Run in this directory to build and run the app:

```shell
docker compose up
```

The `vote` app will be running at [http://localhost:8080](http://localhost:8080), and the `results` will be at [http://localhost:8081](http://localhost:8081).

Alternately, if you want to run it on a [Docker Swarm](https://docs.docker.com/engine/swarm/), first make sure you have a swarm. If you don't, run:

```shell
docker swarm init
```

Once you have your swarm, in this directory run:

```shell
docker stack deploy --compose-file docker-stack.yml vote
```

## Run the app in Kubernetes

The folder k8s-specifications contains the YAML specifications of the Voting App's services.

Run the following command to create the deployments and services. Note it will create these resources in your current namespace (`default` if you haven't changed it.)

```shell
kubectl create -f k8s-specifications/
```

The `vote` web app is then available on port 31000 on each host of the cluster, the `result` web app is available on port 31001.

To remove them, run:

```shell
kubectl delete -f k8s-specifications/
```

## Architecture

![Architecture diagram](architecture.excalidraw.png)

* A front-end web app in [Python](/vote) which lets you vote between two options
* A [Redis](https://hub.docker.com/_/redis/) which collects new votes
* A [.NET](/worker/) worker which consumes votes and stores them in…
* A [Postgres](https://hub.docker.com/_/postgres/) database backed by a Docker volume
* A [Node.js](/result) web app which shows the results of the voting in real time

## Notes

The voting application only accepts one vote per client browser. It does not register additional votes if a vote has already been submitted from a client.

This isn't an example of a properly architected perfectly designed distributed app... it's just a simple
example of the various types of pieces and languages you might see (queues, persistent data, etc), and how to
deal with them in Docker at a basic level.

---

# DevOps Capstone

## Project overview

This project extends the Example Voting App with container security, automated CI/CD, Kubernetes deployment using Helm, and infrastructure provisioning with Terraform.

The application contains the following components:

- **Vote:** Python web application for submitting a vote.
- **Redis:** Queue for incoming votes.
- **Worker:** .NET service that transfers votes from Redis to PostgreSQL.
- **PostgreSQL:** Persistent database for vote records.
- **Result:** Node.js web application that displays the current voting results.

### Application flow

`Vote → Redis → Worker → PostgreSQL → Result`

## Containerization and security

The application services have Dockerfiles and `.dockerignore` files. The application containers are configured to run as non-root users where applicable.

Build and start the local application from the repository root:

```bash
docker compose up --build -d
```

Check the services:

```bash
docker compose ps
```

View application logs:

```bash
docker compose logs --tail=100
```

Stop the local application:

```bash
docker compose down
```

Review each Dockerfile and Compose configuration before making changes to image versions, user permissions, or exposed ports.

## CI/CD with GitHub Actions

The GitHub Actions workflow is defined in:

`.github/workflows/ci-cd.yml`

The workflow validates the application and builds, scans, and publishes container images to GitHub Container Registry (GHCR).

### Verified successful workflow run

- **Workflow:** Voting App CI
- **Branch:** `main`
- **Run ID:** `40036497015`
- **Commit:** `408c12d6ed945c5530384f096ccb32f14aac4c77`
- **Conclusion:** Success

All five jobs passed in this run:

1. Test application
2. Build, scan, and publish seed-data image
3. Build, scan, and publish worker image
4. Build, scan, and publish result image
5. Build, scan, and publish vote image

[View the successful GitHub Actions run](https://github.com/StormyAyo/example-voting-app/actions/runs/40036497015)

### Published application images

The following GHCR packages were checked and contain the successful workflow commit tag:

- `ghcr.io/stormyayo/example-voting-app-vote`
- `ghcr.io/stormyayo/example-voting-app-result`
- `ghcr.io/stormyayo/example-voting-app-worker`

Verified tag:

`408c12d6ed945c5530384f096ccb32f14aac4c77`

The deployed application-fix image tag is:

`e60910fdc9b606d7354f40849ea13ca42091274e`

Use an image tag that exists in GHCR when deploying. The CI workflow commit and deployed application image tag may differ because they represent different commits.

## Kubernetes deployment with Helm

The Helm chart is located at:

`helm/voting-app/`

Validate the chart:

```bash
helm lint helm/voting-app
```

Render the Kubernetes manifests locally:

```bash
helm template voting helm/voting-app \
  --namespace default \
  --values helm/voting-app/values.yaml
```

Deploy or upgrade the release:

```bash
helm upgrade --install voting helm/voting-app \
  --namespace default \
  --values helm/voting-app/values.yaml \
  --wait \
  --timeout 5m
```

Check the release and deployed resources:

```bash
helm status voting --namespace default
helm history voting --namespace default
kubectl get deployments,pods,services,pvc --namespace default
```

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

### Persistent storage

PostgreSQL uses the `voting-postgres-data` persistent volume claim. The verified deployment had a bound 2 GiB claim using the `gp2` StorageClass.

**Important:** Do not delete the PostgreSQL PVC when troubleshooting or uninstalling the Helm release if you need to preserve stored votes. Review the reclaim policy and backup requirements before deleting persistent storage.

## Helm rollback validation

A controlled bad image-tag upgrade was tested using the tag `bad-demo-tag`. The upgrade failed as expected, and the release was rolled back to the known-good revision.

The rollback command was:

```bash
helm rollback voting 2 \
  --namespace default \
  --wait \
  --timeout 5m
```

The rollback completed successfully. Subsequent checks showed all five application deployments available, their pods running, and the PostgreSQL PVC bound.

Inspect the current release history before performing another rollback:

```bash
helm history voting --namespace default
```

Revision numbers can change as new upgrades and rollbacks are performed.

## End-to-end application validation

The deployed application was tested by submitting votes through the vote interface and checking the results interface.

Validation evidence:

- Vote interface loaded.
- Results interface loaded.
- Worker logs showed votes being processed.
- Result application logs confirmed a database connection.
- Submitting a vote and refreshing the results interface showed the updated selection.
- All five deployments were available after rollback.
- PostgreSQL persistent storage was bound.

The application permits one vote per client browser. Submitting a different selection from the same browser updates that client's vote rather than creating an additional independent voter.

## Infrastructure as code with Terraform

Terraform configuration is maintained in the `terraform/` directory.

Run Terraform commands from that directory:

```bash
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Review the plan before applying infrastructure changes. Confirm the AWS account, region, cluster configuration, and estimated costs.

To provision infrastructure, use `terraform apply` only after reviewing and approving the plan. To remove infrastructure, review `terraform plan -destroy` before approving `terraform destroy`.

Destroying infrastructure can interrupt the application and may affect persistent data. Follow the project's storage backup and recovery requirements before cleanup.

## Secrets and operational safety

- Do not commit passwords, access keys, tokens, or kubeconfig credentials.
- Use GitHub Actions secrets or an appropriate secret manager for credentials.
- Review image scan results and update deprecated GitHub Actions when needed.
- Use commit-SHA image tags for reproducible deployments.
- Verify deployment health after upgrades and rollbacks.
- Review AWS costs and clean up resources that are no longer required.

## Capstone evidence

- [Successful GitHub Actions run](https://github.com/StormyAyo/example-voting-app/actions/runs/40036497015)
- Source repository: https://github.com/StormyAyo/example-voting-app
- Helm chart: `helm/voting-app/`
- Terraform configuration: `terraform/`
