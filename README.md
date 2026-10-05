# Production-Style AWS Infrastructure

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.10-844FBA?logo=terraform&logoColor=white)
![AWS Provider](https://img.shields.io/badge/AWS%20provider-6.x-FF9900?logo=amazonaws&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-%E2%89%A5%208.1-777BB4?logo=php&logoColor=white)
![MySQL](https://img.shields.io/badge/Amazon%20RDS-MySQL-4479A1?logo=mysql&logoColor=white)

Terraform-managed AWS infrastructure for a small PHP task manager. The project demonstrates a modular, multi-tier deployment with public and private subnets, an Application Load Balancer, an EC2 Auto Scaling group, and a private MySQL database.

> [!WARNING]
> This is a learning/demo project, not a production-ready service. The task manager is publicly accessible over unencrypted HTTP and has no user authentication: anyone with its URL can view, create, update, or delete tasks. Do not store real or sensitive data. Terraform state and EC2 user data contain credentials and must be protected.

## Demo

![Deployment workflow](docs/assets/demo.gif)

*Illustrative walkthrough of the deployment workflow described below. It uses placeholder values and is not a recording of a real AWS account.*

## Table of contents

- [Features](#features)
- [Architecture](#architecture)
- [Tech stack](#tech-stack)
- [Repository layout](#repository-layout)
- [Requirements](#requirements)
- [Deploy](#deploy)
- [Configuration reference](#configuration-reference)
- [Outputs](#outputs)
- [Run the application locally](#run-the-application-locally)
- [Operational notes](#operational-notes)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

**Infrastructure**

- **Network:** VPC, two public subnets, two private subnets, internet gateway, and routing through a NAT gateway across two Availability Zones.
- **Application tier:** internet-facing Application Load Balancer and an EC2 Auto Scaling group running Apache and PHP in private subnets.
- **Database:** encrypted, private, multi-AZ Amazon RDS for MySQL.
- **Security groups:** application instances accept traffic from the load balancer; MySQL accepts traffic from the application tier.
- **State bucket:** separate bootstrap configuration with S3 versioning, server-side encryption, and public access blocked.

**Sample application**

- Create, list, update, filter, and delete tasks with a title, description, status, and optional due date.
- Prepared SQL statements and short-lived signed CSRF tokens; no PHP/MySQL session dependency.
- Responsive HTML and CSS frontend.
- ALB health check at `/health.php` that verifies the PHP runtime and the RDS connection.
- Footer shows the hostname and private IP of the EC2 instance that served the page.

## Architecture

```mermaid
flowchart LR
    User((User)) -->|HTTP :80| ALB
    subgraph VPC["AWS VPC — two Availability Zones"]
        subgraph Public["Public subnets"]
            ALB["Application Load Balancer"]
            NAT["NAT Gateway"]
        end
        subgraph PrivateApp["Private application subnets"]
            ASG["EC2 Auto Scaling Group<br/>Apache + PHP :3000"]
        end
        subgraph PrivateData["Private database subnets"]
            DB[("Amazon RDS for MySQL<br/>not publicly accessible")]
        end
        ALB -->|HTTP :3000| ASG
        ASG -->|MySQL :3306| DB
        ASG --> NAT
    end
    S3[("Amazon S3<br/>Terraform remote state")] -.-> Terraform["Terraform"]
    Terraform -.-> VPC
```

Terraform creates the network, security rules, application tier, and database as separate modules. The `bootstrap/` configuration creates the S3 bucket used by the root configuration for remote state.

## Tech stack

| Layer | Technology |
| --- | --- |
| Infrastructure as code | Terraform 1.10+ (AWS provider 6.x) |
| Remote state | Amazon S3 |
| Networking | Amazon VPC, NAT gateway, internet gateway |
| Load balancing | Application Load Balancer |
| Compute | EC2 Auto Scaling group (launch template with user data) |
| Web server / runtime | Apache, PHP 8.1+ (PDO MySQL, `mbstring`) |
| Database | Amazon RDS for MySQL |

## Repository layout

```text
.
├── application/
│   ├── deploy/                  # EC2 user-data template
│   └── public/                  # PHP app, health checks, and CSS
├── bootstrap/                   # Creates the Terraform state bucket
├── docs/
│   └── assets/
│       └── demo.gif             # Deployment workflow animation
├── modules/
│   ├── application/             # Load balancer, launch template, Auto Scaling
│   ├── database/                # RDS MySQL resources
│   ├── network/                 # VPC, subnets, and routes
│   └── security/                # Security groups and rules
├── backend.tf                   # Root S3 backend configuration
├── main.tf                      # Provider and module wiring
├── moved.tf                     # Terraform state address migrations
├── outputs.tf                   # Deployment outputs
└── variables.tf                 # Root input variables
```

See [application/README.md](application/README.md) for details about the PHP application.

## Requirements

- Terraform **1.10 or newer**
- An AWS account and credentials configured for the AWS provider
- Permissions to create the VPC, EC2, ELB, RDS, and S3 resources used by the configuration
- An S3 bucket name that is globally unique, for Terraform state

The AWS provider is constrained to the `6.x` release series. The default deployment region is `us-east-1`, and the default availability zones are `us-east-1a` and `us-east-1b`; change them if needed for your account and region.

## Deploy

### 1. Configure the remote state bucket

The checked-in `backend.tf` contains a bucket name from the original environment. Before using this project, choose a globally unique bucket name you control. Set the same name in `bootstrap/variables.tf` (or pass it as a variable) and in the `bucket` setting in the root `backend.tf`.

Create the bucket first:

```sh
cd bootstrap
terraform init
terraform apply -var="bucket_name=your-globally-unique-state-bucket"
cd ..
```

The bootstrap configuration uses local state by default. Keep that local bootstrap state private and backed up. The root configuration stores its state in the S3 bucket.

### 2. Configure credentials and application secrets

Create a private `terraform.tfvars` file in the project root:

```hcl
aws_region          = "us-east-1"
availability_zones  = ["us-east-1a", "us-east-1b"]
db_password         = "replace-with-a-unique-database-password"
app_admin_username  = "admin"
app_admin_password  = "replace-with-a-unique-password-at-least-12-characters"
app_session_secret  = "replace-with-a-random-secret-at-least-32-characters"
```

Generate a session secret with:

```sh
openssl rand -hex 32
```

Use unique values and never commit `terraform.tfvars`, credentials, state files, or plan files. You can also inject the sensitive values through `TF_VAR_` environment variables instead of a file.

> [!IMPORTANT]
> Sensitive Terraform variables are still stored in Terraform state and in EC2 launch-template user data. Treat both as secrets.

### 3. Initialize and deploy

From the project root:

```sh
terraform init
terraform validate
terraform plan
terraform apply
```

If you change the S3 backend configuration after a previous initialization, review Terraform's state migration prompt carefully. Use `terraform init -reconfigure` only when you intend to connect to the newly configured backend without migrating existing state.

On first launch, EC2 user data installs Apache and PHP with PDO MySQL support, deploys the application files, configures Apache to listen on port 3000, and enables the service. The application creates its tables and the shared internal database owner on first launch.

### 4. Open the application

```sh
terraform output -raw alb_dns_name
```

Open the output using `http://`, for example `http://<alb-dns-name>`. Wait for the Auto Scaling group instances to become healthy behind the load balancer.

The Auto Scaling group replaces instances when the launch template changes; wait for the new instances to pass the ALB health check before removing old instances.

## Configuration reference

| Variable | Required | Description |
| --- | --- | --- |
| `aws_region` | No | AWS deployment region; defaults to `us-east-1`. |
| `availability_zones` | No | Two AZs for the network; defaults to `us-east-1a` and `us-east-1b`. |
| `db_password` | Yes | Master password for the MySQL database. |
| `app_admin_username` | No | Internal seed account name; defaults to `admin`. |
| `app_admin_password` | Yes | Internal seed account password; at least 12 characters. |
| `app_session_secret` | Yes | Application signing secret used to validate short-lived CSRF tokens; at least 32 characters. |

The app is currently a shared public workspace. The seed account owns the shared data internally and is **not** a login for the public website.

## Outputs

| Output | Description |
| --- | --- |
| `alb_dns_name` | DNS name of the public Application Load Balancer. |
| `autoscaling_group_name` | Name of the application Auto Scaling group. |
| `vpc_id` | ID of the created VPC. |
| `public_subnet_ids` | IDs of the public subnets. |
| `private_subnet_ids` | IDs of the private subnets. |
| `rds_endpoint` | RDS MySQL endpoint. |
| `rds_port` | RDS MySQL port. |
| `alb_security_group_id` | Security group ID for the load balancer. |
| `ec2_security_group_id` | Security group ID for application instances. |
| `rds_security_group_id` | Security group ID for the database. |

## Run the application locally

Requirements: PHP 8.1 or newer with the PDO MySQL and `mbstring` extensions, and a MySQL database.

1. Create a JSON config file containing `db_host`, `db_port`, `db_name`, `db_username`, `db_password`, `admin_username`, `admin_password`, and `session_secret`.
2. Point the app at it with the `APP_CONFIG_PATH` environment variable.
3. Configure Apache to serve `application/public/` with PHP enabled.

`public/health.php` is the load balancer health endpoint. The signing secret validates short-lived CSRF tokens and does not require PHP sessions.

## Operational notes

- **Costs:** this stack creates billable resources, including a NAT Gateway, load balancer, EC2 instances, and a multi-AZ RDS database. Review AWS pricing before applying, and remove resources when you are finished.
- **HTTP only:** the load balancer listens on port 80 and forwards HTTP to the application on port 3000. No HTTPS listener or port-443 security-group rule is configured.
- **Public app:** there is no public user authentication or authorization. Anyone who can reach the load balancer can change shared task data.
- **Database recovery:** the current RDS configuration has zero-day automated backup retention and skips the final snapshot on deletion. Do not use it for data that needs recovery.
- **Secrets and state:** `.gitignore` excludes Terraform state and `.tfvars` files, but verify what will be published before pushing to GitHub. Do not publish state, secrets, real configuration values, or AWS account details.

## Troubleshooting

**The `http://` URL redirects to HTTPS or fails in Chrome.** If the hostname was previously opened and Chrome upgrades it to HTTPS automatically, remove its cached HSTS policy at `chrome://net-internals/#hsts` under **Delete domain security policies**, then open the `http://` URL in a new tab.

**The site is not reachable right after `terraform apply`.** Instances need time to launch and pass the ALB health check at `/health.php`. Wait for the Auto Scaling group instances to become healthy, then retry.

**Security-group or cookie changes are not taking effect.** Terraform must be applied for these changes to reach AWS.

## License

No license is currently included. Add a license file before accepting or granting reuse of this project.