# Production-Style AWS Infrastructure

Terraform-managed AWS infrastructure for a small PHP task manager. The project
demonstrates a modular, multi-tier deployment with public and private subnets,
an Application Load Balancer, an EC2 Auto Scaling group, and a private MySQL
database.

> [!WARNING]
> This is a learning/demo project, not a production-ready service. The task
> manager is publicly accessible over unencrypted HTTP and has no user
> authentication: anyone with its URL can view, create, update, or delete
> tasks. Do not store real or sensitive data. Terraform state and EC2 user
> data contain credentials and must be protected.

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

Terraform creates the network, security rules, application tier, and database
as separate modules. The `bootstrap/` configuration creates the S3 bucket used
by the root configuration for remote state.

## What it includes

- **Network:** VPC, two public subnets, two private subnets, internet gateway,
  and routing through a NAT gateway.
- **Application:** internet-facing Application Load Balancer and an EC2 Auto
  Scaling group running Apache and PHP in private subnets.
- **Database:** encrypted, private, multi-AZ Amazon RDS for MySQL.
- **Security groups:** application instances accept traffic from the load
  balancer; MySQL accepts traffic from the application tier.
- **State bucket:** separate bootstrap configuration with S3 versioning,
  server-side encryption, and public access blocked.
- **Sample application:** shared PHP task CRUD app with a database-backed
  health check.

## Repository layout

```text
.
├── application/
│   ├── deploy/                  # EC2 user-data template
│   └── public/                  # PHP app, health checks, and CSS
├── bootstrap/                   # Creates the Terraform state bucket
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

See [application/README.md](application/README.md) for details about the PHP
application.

## Requirements

- Terraform **1.10 or newer**
- An AWS account and credentials configured for the AWS provider
- Permissions to create the VPC, EC2, ELB, RDS, and S3 resources
  used by the configuration
- An S3 bucket name that is globally unique for Terraform state

The AWS provider is constrained to the `6.x` release series. The default
deployment region is `us-east-1`, and the default availability zones are
`us-east-1a` and `us-east-1b`; change them if needed for your account and
region.

## Deploy

### 1. Configure the remote state bucket

The checked-in `backend.tf` contains a bucket name from the original
environment. Before using this project, choose a globally unique bucket name
you control. Set the same name in `bootstrap/variables.tf` (or pass it as a
variable) and in the `bucket` setting in the root `backend.tf`.

Create the bucket first:

```sh
cd bootstrap
terraform init
terraform apply -var="bucket_name=your-globally-unique-state-bucket"
cd ..
```

The bootstrap configuration uses local state by default. Keep that local
bootstrap state private and backed up. The root configuration stores its state
in the S3 bucket.

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

Generate a session secret, for example, with `openssl rand -hex 32`. Use
unique values and never commit `terraform.tfvars`, credentials, state files, or
plan files. Sensitive Terraform variables are still stored in Terraform state
and in EC2 launch-template user data; treat both as secrets.

| Variable | Required | Description |
| --- | --- | --- |
| `aws_region` | No | AWS deployment region; defaults to `us-east-1`. |
| `availability_zones` | No | Two AZs for the network; defaults to `us-east-1a` and `us-east-1b`. |
| `db_password` | Yes | Master password for the MySQL database. |
| `app_admin_username` | No | Internal seed account name; defaults to `admin`. |
| `app_admin_password` | Yes | Internal seed account password; at least 12 characters. |
| `app_session_secret` | Yes | Application signing secret; at least 32 characters. |

The app is currently a shared public workspace; its seed account is not a
login for the public website.

### 3. Initialize and deploy

From the project root:

```sh
terraform init
terraform validate
terraform plan
terraform apply
```

If you change the S3 backend configuration after a previous initialization,
review Terraform's state migration prompt carefully. Use `terraform init
-reconfigure` only when you intend to connect to the newly configured backend
without migrating existing state.

After deployment, get the application URL with:

```sh
terraform output -raw alb_dns_name
```

Open the output using `http://`. Wait for the Auto Scaling group instances to
become healthy behind the load balancer.

## Important operational notes

- **Costs:** this stack creates billable resources, including a NAT Gateway,
  load balancer, EC2 instances, and a multi-AZ RDS database. Review AWS
  pricing and your plan before applying, and remove resources when you are
  finished if appropriate.
- **HTTP only:** the load balancer listens on port 80 and forwards HTTP to the
  application. HTTPS is not configured.
- **Public app:** there is no public user authentication or authorization.
  Anyone who can reach the load balancer can change shared task data.
- **Database recovery:** the current RDS configuration has zero-day automated
  backup retention and skips the final snapshot on deletion. Do not use it for
  data that needs recovery.
- **Secrets and state:** `.gitignore` excludes Terraform state and `.tfvars`
  files, but verify what will be published before pushing to GitHub. Do not
  publish state, secrets, real configuration values, or AWS account details.

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

## License

No license is currently included. Add a license file before accepting or
granting reuse of this project.
