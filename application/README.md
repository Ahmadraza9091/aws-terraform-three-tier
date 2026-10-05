# Production Task Manager

An Apache-hosted PHP task CRUD web application deployed by the Terraform application module. It is temporarily configured as a shared, public workspace: anyone with the ALB URL can view, create, edit, or delete tasks. Data is stored in the private RDS MySQL database.

## Features

- Create, list, update, filter, and delete tasks with a title, description, status, and optional due date.
- Shared task ownership, prepared SQL statements, and short-lived signed CSRF tokens; no PHP/MySQL session dependency.
- Responsive HTML and CSS frontend with an ALB `/health.php` check that verifies the PHP runtime and RDS connection.
- The footer displays the hostname and private IP of the EC2 instance that served the page.

## Configure application seed values

Set these sensitive Terraform variables in a private `terraform.tfvars` file or inject them through `TF_VAR_` environment variables. The configured username and password seed the shared internal database owner; they are not required to use the public website.

```hcl
app_admin_username = "admin"
app_admin_password = "use-a-unique-password-at-least-12-characters"
app_session_secret = "use-a-random-secret-at-least-32-characters-long"
```


Generate an application signing secret with `openssl rand -hex 32`. Do not commit credentials or place real values in this example. The MySQL master password is provided separately through the existing `db_password` variable. Terraform state and launch-template user data contain sensitive configuration; protect access to both.

On first launch the service creates its tables and shared internal database owner. Keep Terraform state and `terraform.tfvars` private because the password is included in Terraform-managed configuration.

## Deploy

Apply the root Terraform configuration after setting `db_password`, `app_admin_password`, and `app_session_secret`. EC2 user data installs Apache and PHP with PDO MySQL support, deploys the application files, configures Apache to listen on port 3000, and enables the service. The Auto Scaling Group replaces instances when the launch template changes; wait for the new instances to pass the ALB health check before removing old instances.

The application is intentionally HTTP-only: the ALB listens on port 80 and forwards to the private app instances on port 3000. No HTTPS listener or public port-443 security-group rule is configured. Use the `http://` URL from the root `alb_dns_name` output. Since authentication is disabled, anyone with the link can alter or remove shared task data. HTTP traffic is unencrypted; use only in a trusted test environment and do not store sensitive information.

If this hostname was previously opened in Chrome and automatically upgrades to HTTPS, remove its cached HSTS policy at `chrome://net-internals/#hsts` under **Delete domain security policies**, then open the `http://` URL in a new tab. Terraform must be applied for the security-group rule and application cookie changes to reach AWS.

## Run locally

Use PHP 8.1 or newer with PDO MySQL and `mbstring` extensions and a MySQL database. Set `APP_CONFIG_PATH` to a JSON file containing `db_host`, `db_port`, `db_name`, `db_username`, `db_password`, `admin_username`, `admin_password`, and `session_secret`. Configure Apache to serve `public/` with PHP enabled; `public/health.php` is the load balancer health endpoint. The signing secret is used to validate short-lived CSRF tokens and does not require PHP sessions.
