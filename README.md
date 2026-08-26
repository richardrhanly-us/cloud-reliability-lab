**# Cloud Reliability Lab**

![Tests]\(https\://github.com/richardrhanly-us/cloud-reliability-lab/actions/workflows/test.yml/badge.svg)

Production-style cloud reliability lab built to practice Linux systems administration, infrastructure automation, monitoring, incident response, and SRE-style operations.

The project began as a manually configured Ubuntu homelab deployment and has since been expanded into a reproducible AWS environment using Amazon EC2, IAM, Systems Manager, CloudWatch, Terraform, and S3-backed remote Terraform state.

**## Overview**

The Cloud Reliability Lab is a hands-on infrastructure and operations project demonstrating how a small web service can be deployed, monitored, intentionally broken, recovered, and documented.

The project currently includes two environments.

**### AWS Deployment**

\- Amazon Linux 2023 EC2 application server

\- Terraform-managed AWS infrastructure

\- Dedicated VPC and public subnet

\- Internet gateway and public route table

\- Security group exposing HTTP only

\- IAM instance role

\- AWS Systems Manager Session Manager for administration

\- No public SSH access

\- Automated EC2 bootstrap using Terraform \`user\_data\`

\- FastAPI / Uvicorn application

\- systemd service management

\- nginx reverse proxy

\- CloudWatch Agent log forwarding

\- dedicated systemd/journald failure-event forwarding

\- CloudWatch Logs metric filter for application service failures

\- CloudWatch systemd failure alarm

\- CloudWatch CPU alarm

\- S3 remote Terraform state

\- Terraform state locking

\- Versioned and encrypted S3 state storage

**### Original Homelab Deployment**

\- Ubuntu Server

\- FastAPI application

\- systemd service management

\- nginx reverse proxy

\- \`/health\` monitoring

\- journald and nginx logs

\- Uptime Kuma monitoring

\- controlled failure testing

\- operational runbooks

\- incident reports

\- validation screenshots

The homelab environment was used to develop and validate the service and failure scenarios before moving the architecture into AWS.

The AWS deployment extends the project with Infrastructure as Code, automated provisioning, centralized logging, remote administration, monitoring, and shared Terraform state.

The purpose of the project is not simply to deploy an application. The goal is to practice the operational work involved in keeping services reliable.

**## Current Architecture**

![Cloud Reliability Lab AWS Architecture]\(screenshots/Architecture-diagram.png)

The AWS deployment uses a Terraform-managed VPC, public subnet, security group, IAM role, EC2 instance, CloudWatch logging and monitoring, Systems Manager access, and S3-backed remote Terraform state.

\`\`\`text

                           Internet

                              |

                              v

                    AWS Security Group

                       HTTP :80 only

                              |

                              v

                         Amazon EC2

                      Amazon Linux 2023

                              |

                              v

                          nginx :80

                              |

                              v

                    FastAPI / Uvicorn

                      127.0.0.1:8000

                              |

                              v

                           systemd

                              |

               +--------------+--------------+

               |                             |

               v                             v

       Application Logs                 nginx Logs

               |                             |

               +--------------+--------------+

                              |

                              v

                     CloudWatch Agent

                              |

                              v

                      CloudWatch Logs



Terraform

   |

   +--> VPC / Subnet / Routing

   +--> Security Group

   +--> IAM / SSM Permissions

   +--> EC2

   +--> CloudWatch Alarm

   |

   v

S3 Remote State

Versioning + Encryption + State Locking

\## Technology Stack

\| Component | Purpose |

\| --- | --- |

\| Amazon EC2 | AWS compute host |

\| Amazon Linux 2023 | EC2 operating system |

\| Terraform | Infrastructure as Code |

\| Amazon S3 | Remote Terraform state |

\| AWS IAM | EC2 permissions and instance role |

\| AWS Systems Manager | Administrative access without public SSH |

\| Amazon CloudWatch | Centralized logs, metrics, and alarms |

\| CloudWatch Agent | Ships application, nginx, and exported systemd lifecycle logs to CloudWatch |

\| FastAPI | Python web application framework |

\| Uvicorn | ASGI application server |

\| systemd | Service management and automatic restart |

\| nginx | Public-facing reverse proxy |

\| GitHub Actions | Automated application testing |

\| pytest | Python test framework |

\| Git | Version control and infrastructure history |

\| Ubuntu Server | Original homelab environment |

\| Uptime Kuma | Original homelab health monitoring |

\## Application Endpoints

\| Endpoint | Purpose |

\| --- | --- |

\| \`/\` | Basic application status |

\| \`/health\` | Application health check |

\| \`/ready\` | Database dependency readiness check |

\| \`/version\` | Application version |

Example AWS health check:

\`\`\`bash

curl http\://\<EC2\_PUBLIC\_IP>/health

\`\`\`

The current EC2 public IP can be retrieved through Terraform:

\`\`\`bash

terraform output -raw ec2\_public\_ip

\`\`\`

Example response:

\`\`\`json

{

  "status": "ok",

  "hostname": "ip-10-20-1-221.ec2.internal",

  "started\_at": "2026-08-25T21:29:32.573054+00:00",

  "checked\_at": "2026-08-25T22:06:57.875909+00:00"

}

\`\`\`

The \`/ready\` endpoint is designed to validate a PostgreSQL dependency. The current AWS environment does not yet include an AWS-hosted PostgreSQL database, so database readiness is a future infrastructure expansion.

**## Automated AWS Deployment**

The EC2 application server is provisioned by Terraform and configured automatically through a bootstrap script passed to EC2 as \`user\_data\`.

The bootstrap process:

1\. Updates Amazon Linux packages.

2\. Installs Git, nginx, Python 3.11, and the CloudWatch Agent.

3\. Creates a dedicated \`cloudlab\` system user.

4\. Clones the application repository.

5\. Creates the Python virtual environment.

6\. Installs application dependencies.

7\. Creates the application log directory.

8\. Installs and enables the application and systemd journal-export services.

9\. Configures nginx.

10\. Configures and starts the CloudWatch Agent for application, nginx, and systemd lifecycle logs.

11\. Starts the application and nginx.

12\. Performs local health checks before completing.

The bootstrap script is stored at:

\`\`\`text

scripts/aws-bootstrap.sh

\`\`\`

The automated deployment was validated by replacing the original manually configured AWS EC2 instance with a Terraform-created replacement.

The replacement successfully:

\- bootstrapped the application without manual server configuration

\- started the systemd-managed FastAPI service

\- configured nginx

\- returned successful \`/health\` and \`/version\` responses

\- registered with AWS Systems Manager

\- began sending application logs to CloudWatch

\- updated the Terraform-managed CloudWatch CPU alarm to the new instance ID

This validates that the AWS application server can be recreated from code rather than relying on manual configuration.

**## Infrastructure as Code**

Terraform manages the AWS infrastructure for the lab.

Managed resources include:

\- VPC

\- public subnet

\- internet gateway

\- public route table

\- default internet route

\- route table association

\- security group

\- HTTP ingress rule

\- outbound security group rule

\- EC2 IAM role

\- IAM instance profile

\- Systems Manager policy attachment

\- CloudWatch Agent policy attachment

\- EC2 application instance

\- CloudWatch CPU alarm

\- CloudWatch Logs metric filter for systemd application failures

\- CloudWatch systemd failure alarm

Terraform configuration is stored in:

\`\`\`text

terraform/

\`\`\`

The configuration is organized into sections for:

\`\`\`text

Shared Configuration

Amazon Linux 2023 AMI

Networking

Security Group

EC2 IAM, SSM, and CloudWatch Permissions

EC2 Application Server

CloudWatch Monitoring

\`\`\`

After infrastructure changes are applied, \`terraform plan\` is used to verify that the live AWS environment matches the declared configuration.

A clean deployment returns:

\`\`\`text

No changes. Your infrastructure matches the configuration.

\`\`\`

**## Terraform Remote State**

Terraform state is stored remotely in Amazon S3 rather than being tied to an individual development workstation.

Backend configuration is stored in:

\`\`\`text

terraform/backend.tf

\`\`\`

The Terraform state object is stored at:

\`\`\`text

cloud-reliability-lab/terraform.tfstate

\`\`\`

The S3 state bucket uses:

\- versioning

\- server-side encryption

\- blocked public access

\- Terraform state locking

This allows the infrastructure to be managed consistently from multiple development machines while maintaining a shared authoritative state.

Local Terraform state files are excluded from Git.

**## Service Management**

The FastAPI application runs as a systemd service.

Service name:

\`\`\`text

cloud-reliability-lab.service

\`\`\`

Check service status:

\`\`\`bash

sudo systemctl status cloud-reliability-lab

\`\`\`

Restart the service:

\`\`\`bash

sudo systemctl restart cloud-reliability-lab

\`\`\`

The AWS deployment uses:

\`\`\`text

systemd/cloud-reliability-lab-aws.service

\`\`\`

The original homelab deployment configuration is also retained in the repository:

\`\`\`text

systemd/cloud-reliability-lab.service

\`\`\`

The AWS service runs the application as the dedicated \`cloudlab\` system user.

Application output is written to:

\`\`\`text

/var/log/cloud-reliability-lab/app.log

\`\`\`

**## Reverse Proxy**

nginx listens on port \`80\` and forwards traffic to the FastAPI application running locally on \`127.0.0.1:8000\`.

This keeps Uvicorn bound to localhost while nginx handles client-facing HTTP traffic.

\`\`\`text

Client request

      |

      v

nginx :80

      |

      v

Uvicorn 127.0.0.1:8000

\`\`\`

nginx access log:

\`\`\`bash

sudo tail -n 20 /var/log/nginx/cloud-reliability-lab-access.log

\`\`\`

nginx error log:

\`\`\`bash

sudo tail -n 20 /var/log/nginx/cloud-reliability-lab-error.log

\`\`\`

The nginx configuration is included in:

\`\`\`text

nginx/cloud-reliability-lab.conf

\`\`\`

**## Monitoring and Logging**

**### AWS CloudWatch**

The AWS deployment uses the CloudWatch Agent to centralize application, nginx, and systemd lifecycle logs.

Current CloudWatch log groups:

\`\`\`text

/cloud-reliability-lab/app

/cloud-reliability-lab/nginx/access

/cloud-reliability-lab/nginx/error

/cloud-reliability-lab/systemd

\`\`\`

Each EC2 instance writes to a log stream identified by its EC2 instance ID.

Application logs are written locally to:

\`\`\`text

/var/log/cloud-reliability-lab/app.log

\`\`\`

nginx logs are written locally to:

\`\`\`text

/var/log/nginx/cloud-reliability-lab-access.log

/var/log/nginx/cloud-reliability-lab-error.log

\`\`\`

systemd lifecycle events for the application are exported from journald to:

\`\`\`text

/var/log/cloud-reliability-lab/systemd.log

\`\`\`

The journal export is managed by:

\`\`\`text

cloud-reliability-journal-export.service

\`\`\`

The exporter follows events for \`cloud-reliability-lab.service\` and writes them to the dedicated systemd log. The CloudWatch Agent then forwards that log into \`/cloud-reliability-lab/systemd\`.

The CloudWatch Agent configuration is stored at:

\`\`\`text

cloudwatch/amazon-cloudwatch-agent.json

\`\`\`

**### CloudWatch CPU Alarm**

Terraform manages the alarm:

\`\`\`text

cloud-reliability-lab-high-cpu

\`\`\`

The alarm monitors:

\`\`\`text

Metric: CPUUtilization

Statistic: Average

Threshold: 80%

Period: 5 minutes

Evaluation periods: 2

\`\`\`

The alarm enters the alarm state if average EC2 CPU utilization remains above 80 percent for two consecutive five-minute periods.

**### CloudWatch systemd Failure Alarm**

Terraform also manages an application-process failure alarm:

\`\`\`text

cloud-reliability-lab-systemd-failure

\`\`\`

Application service failures are detected from the centralized systemd log group:

\`\`\`text

/cloud-reliability-lab/systemd

\`\`\`

A CloudWatch Logs metric filter searches for:

\`\`\`text

Failed with result

\`\`\`

Matching events publish the custom metric:

\`\`\`text

Namespace: CloudReliabilityLab

Metric: SystemdFailureCount

Value: 1

\`\`\`

The alarm evaluates the metric over a 60-second period and enters \`ALARM\` when at least one application service failure is detected.

The monitoring path was validated using a controlled \`SIGKILL\` of the Uvicorn process. systemd detected the failure, automatically restarted the service, the journal exporter forwarded the lifecycle events to CloudWatch Logs, the metric filter emitted a failure datapoint, and the CloudWatch alarm entered \`ALARM\`.

The validated alarm state reported:

\`\`\`text

Threshold Crossed: 1 datapoint was greater than or equal to the threshold (1.0).

State: ALARM

\`\`\`

Alarm notification delivery is not yet configured; adding SNS or another notification destination is a planned improvement.

**### Homelab Monitoring**

The original Ubuntu deployment uses Uptime Kuma to monitor the \`/health\` endpoint.

The monitor checks the application through nginx, validating both the reverse proxy and the FastAPI backend.

**## Reliability Features**

Current reliability features include:

\- dedicated \`/health\` endpoint

\- dependency-oriented \`/ready\` endpoint

\- systemd-managed application process

\- automatic application restart after failure

\- nginx reverse proxy

\- Uvicorn bound only to localhost

\- local and remote health check validation

\- application logging

\- nginx access and error logging

\- centralized CloudWatch logging

\- dedicated systemd/journald lifecycle-event export

\- centralized systemd failure logging in CloudWatch

\- CloudWatch Logs failure metric filter

\- CloudWatch application-process failure alarm

\- CloudWatch CPU alarm

\- AWS Systems Manager administration

\- automated EC2 provisioning

\- Terraform-managed infrastructure

\- S3 remote state

\- Terraform state locking

\- Uptime Kuma homelab monitoring

\- operational runbooks

\- incident reports

\- controlled failure testing

\- GitHub Actions tests

\- infrastructure drift validation

**## Validation Screenshots**

**### Windows Health Check Through nginx**

![Windows Health Check]\(screenshots/validation/windows-health-check.png)

Windows PowerShell health check confirming that the FastAPI service is reachable from another machine through nginx on port \`80\` and returning HTTP \`200\`.

**### Uptime Kuma Health Monitor**

![Uptime Kuma Health Monitor]\(screenshots/validation/uptime-kuma-health-monitor.png)

Uptime Kuma monitor showing the original homelab \`/health\` endpoint returning successful checks through nginx with response-time and uptime tracking.

**### systemd Automatic Recovery Test**

![systemd Automatic Recovery]\(screenshots/validation/systemd-auto-recovery.png)

Controlled application crash test showing systemd moving the service into an automatic restart state after the FastAPI process was intentionally killed. The \`/health\` endpoint returned successfully after recovery.

**### Service Logs with journalctl**

![journalctl Service Logs]\(screenshots/validation/journalctl-service-logs.png)

\`journalctl\` output showing FastAPI service startup logs and a successful health check request through the systemd-managed service.

**### nginx Reverse Proxy Failure — Incorrect Upstream**

![Incorrect nginx upstream configuration]\(screenshots/incidents/nginx-reverse-proxy-failure/nginx-wrong-upstream-config.png)

Controlled failure configuration showing nginx intentionally changed to proxy requests to \`127.0.0.1:8001\` while the FastAPI application remained on \`127.0.0.1:8000\`.

**### nginx Reverse Proxy Failure — Troubleshooting**

![nginx reverse proxy troubleshooting]\(screenshots/incidents/nginx-reverse-proxy-failure/nginx-failure-troubleshooting.png)

Troubleshooting evidence showing HTTP \`502 Bad Gateway\`, a healthy FastAPI response on port \`8000\`, nginx remaining active, no listener on port \`8001\`, and nginx error logs reporting an upstream connection refusal.

**## Validated Failure Scenarios**

**### Application Crash**

A controlled application failure was triggered using:

\`\`\`bash

sudo systemctl kill cloud-reliability-lab

\`\`\`

systemd detected the stopped service and automatically restarted it.

Recovery was validated using:

\`\`\`bash

sudo systemctl status cloud-reliability-lab

curl http\://127.0.0.1:8000/health

curl http\://127.0.0.1/health

\`\`\`

The original homelab deployment was also validated remotely from another machine.

This confirms that the application can recover automatically from a basic process failure.

**### nginx Reverse Proxy Upstream Failure**

A controlled reverse proxy failure was introduced by changing the nginx upstream from:

\`\`\`text

127.0.0.1:8000

\`\`\`

to:

\`\`\`text

127.0.0.1:8001

\`\`\`

The nginx configuration remained syntactically valid and nginx continued running, but requests through the reverse proxy returned:

\`\`\`text

502 Bad Gateway

\`\`\`

The FastAPI application remained healthy when tested directly on port \`8000\`.

The failure was traced using:

\`\`\`bash

curl http\://127.0.0.1/health

curl http\://127.0.0.1:8000/health

sudo systemctl status nginx --no-pager

ss -ltnp | grep -E ':80|:8000|:8001'

sudo tail -n 30 /var/log/nginx/cloud-reliability-lab-error.log

\`\`\`

Investigation confirmed that:

\- nginx was active on port \`80\`

\- FastAPI/Uvicorn was active on \`127.0.0.1:8000\`

\- no process was listening on port \`8001\`

\- nginx error logs reported an upstream connection refusal

The known-good nginx configuration was restored, validated with \`nginx -t\`, and reloaded successfully.

This scenario demonstrated fault isolation across the HTTP, reverse proxy, TCP listener, application, logging, and configuration layers.

Full incident report:

\`\`\`text

incidents/2026-08-09-nginx-reverse-proxy-failure.md

\`\`\`

**### AWS Application Process Failure**

A controlled application failure was introduced on the AWS EC2 application server by terminating the systemd-managed Uvicorn process with \`SIGKILL\`.

Before the failure:

\`\`\`text

MainPID=26969

NRestarts=0

ActiveState=active

SubState=running

\`\`\`

Immediately after termination, systemd reported:

\`\`\`text

MainPID=0

NRestarts=0

ActiveState=activating

SubState=auto-restart

\`\`\`

After the configured restart delay:

\`\`\`text

MainPID=33465

NRestarts=1

ActiveState=active

SubState=running

\`\`\`

The application recovered automatically without a manual restart.

Recovery was validated through:

\`\`\`bash

curl http\://127.0.0.1:8000/health

curl http\://127.0.0.1/health

\`\`\`

Both health checks returned successfully.

The local systemd journal recorded the process termination and automatic restart, while CloudWatch recorded both the original and replacement Uvicorn startup events:

\`\`\`text

INFO: Started server process [26969]

INFO: Started server process [33465]

\`\`\`

This scenario validated automatic service recovery on the AWS-hosted deployment and confirmed that centralized application logging continued across the restart.

The monitoring path was subsequently extended to centralize the systemd lifecycle events themselves. A dedicated journal exporter now captures \`cloud-reliability-lab.service\` events and forwards them through the CloudWatch Agent to \`/cloud-reliability-lab/systemd\`.

A second controlled \`SIGKILL\` test confirmed that CloudWatch received the systemd failure and recovery sequence, including:

\`\`\`text

Main process exited, code=killed, status=9/KILL

Failed with result 'signal'.

Scheduled restart job

Started cloud-reliability-lab.service

\`\`\`

A Terraform-managed CloudWatch Logs metric filter converted the failure event into the \`CloudReliabilityLab/SystemdFailureCount\` metric. The associated \`cloud-reliability-lab-systemd-failure\` alarm then transitioned to \`ALARM\`.

This validates the full failure-detection chain from process termination through automatic recovery, centralized logging, metric generation, and CloudWatch alarm evaluation.

Full runbook:

\`\`\`text

runbooks/aws-application-process-failure.md

\`\`\`

Full incident report:

\`\`\`text

incidents/2026-08-25-aws-application-process-failure.md

\`\`\`

**## AWS Deployment**

The original homelab architecture has been successfully extended into AWS.

\| AWS Component | Status | Purpose |

\| --- | --- | --- |

\| EC2 | Implemented | Amazon Linux application server |

\| Amazon Linux 2023 | Implemented | Cloud operating system |

\| VPC | Implemented | Isolated project network |

\| Public Subnet | Implemented | Internet-reachable application subnet |

\| Internet Gateway | Implemented | Public connectivity |

\| Route Table | Implemented | Internet routing |

\| Security Group | Implemented | HTTP network access control |

\| IAM Role | Implemented | EC2 permissions |

\| IAM Instance Profile | Implemented | Associates IAM role with EC2 |

\| Systems Manager | Implemented | Administrative access without SSH |

\| CloudWatch Agent | Implemented | Centralized log collection |

\| CloudWatch Logs | Implemented | Application, nginx, and systemd lifecycle log storage |

\| CloudWatch CPU Alarm | Implemented | EC2 CPU monitoring |

\| CloudWatch Log Metric Filter | Implemented | Converts systemd service failures into a custom metric |

\| CloudWatch systemd Failure Alarm | Implemented | Detects application service failures from centralized systemd logs |

\| Terraform | Implemented | Infrastructure as Code |

\| EC2 User Data | Implemented | Automated server bootstrap |

\| S3 Backend | Implemented | Shared remote Terraform state |

\| S3 Versioning | Implemented | State recovery history |

\| S3 Encryption | Implemented | State encryption at rest |

\| Terraform State Locking | Implemented | Concurrent state protection |

**## Project Structure**

\`\`\`text

cloud-reliability-lab/

├── .github/

│   └── workflows/

│       └── test.yml

├── app/

│   └── main.py

├── cloudwatch/

│   └── amazon-cloudwatch-agent.json

├── config/

│   └── app.conf

├── docs/

├── incidents/

│   ├── 2026-08-09-application-crash-recovery.md

│   ├── 2026-08-09-nginx-reverse-proxy-failure.md

│   └── 2026-08-25-aws-application-process-failure.md

├── nginx/

│   └── cloud-reliability-lab.conf

├── runbooks/

│   ├── application-crash.md

│   ├── nginx-reverse-proxy-failure.md

│   └── aws-application-process-failure.md

├── scripts/

│   ├── aws-bootstrap.sh

│   └── cloud-reliability-journal-export.sh

├── screenshots/

│   ├── incidents/

│   │   └── nginx-reverse-proxy-failure/

│   │       ├── nginx-failure-troubleshooting.png

│   │       └── nginx-wrong-upstream-config.png

│   └── validation/

│       ├── journalctl-service-logs.png

│       ├── systemd-auto-recovery.png

│       ├── uptime-kuma-health-monitor.png

│       └── windows-health-check.png

├── systemd/

│   ├── cloud-reliability-lab.service

│   ├── cloud-reliability-lab-aws.service

│   └── cloud-reliability-journal-export.service

├── terraform/

│   ├── backend.tf

│   ├── main.tf

│   ├── outputs.tf

│   ├── providers.tf

│   ├── terraform.tfvars.example

│   └── variables.tf

├── tests/

│   └── test\_app.py

├── requirements.txt

└── README.md

\`\`\`

**## Automated Testing**

Application tests are implemented with \`pytest\`.

Current tests validate:

\- root application endpoint

\- \`/health\`

\- \`/version\`

Run locally:

\`\`\`bash

python -m pytest -v

\`\`\`

GitHub Actions runs the test suite automatically on repository changes.

**## Skills Demonstrated**

This project demonstrates practical experience with:

\- Linux administration

\- Amazon Linux administration

\- AWS EC2

\- AWS VPC networking

\- AWS security groups

\- AWS IAM

\- AWS Systems Manager

\- AWS CloudWatch

\- CloudWatch Agent

\- CloudWatch alarms

\- CloudWatch Logs metric filters

\- log-derived custom CloudWatch metrics

\- Amazon S3

\- Terraform

\- Infrastructure as Code

\- Terraform remote state

\- Terraform state locking

\- infrastructure drift detection

\- automated EC2 bootstrapping

\- Python web service deployment

\- FastAPI application structure

\- systemd service management

\- nginx reverse proxy configuration

\- TCP/IP and HTTP troubleshooting

\- reverse proxy fault isolation

\- TCP listener inspection with \`ss\`

\- HTTP 502 troubleshooting

\- health check design

\- application logging

\- centralized log collection

\- journald log review

\- systemd/journald event forwarding

\- nginx access/error log review

\- automated service recovery

\- incident response documentation

\- runbook creation

\- Git-based infrastructure management

\- GitHub Actions CI

\- pytest

\- SRE-style failure testing

\- reproducible infrastructure deployment

**## Runbooks**

Operational runbooks are stored in the \`runbooks/\` directory.

Current runbooks:

\- \`application-crash.md\` — detecting, investigating, and recovering from an application crash

\- \`nginx-reverse-proxy-failure.md\` — isolating and recovering from a reverse proxy/upstream failure

\- \`aws-application-process-failure.md\` — detecting, validating, and recovering from an unexpected FastAPI/Uvicorn process failure on the AWS EC2 deployment

Planned runbooks:

\- blocked network port

\- high CPU usage

\- disk exhaustion

\- permission failure

\- failed deployment

\- DNS failure

\- Terraform drift

\- failed EC2 bootstrap

**## Incident Reports**

Incident reports are stored in the \`incidents/\` directory.

Current incident reports:

\- \`2026-08-09-application-crash-recovery.md\` — controlled process failure, automatic systemd recovery, validation, and lessons learned

\- \`2026-08-09-nginx-reverse-proxy-failure.md\` — controlled upstream misconfiguration traced through nginx, TCP listeners, application health, and logs to identify the root cause

\- \`2026-08-25-aws-application-process-failure.md\` — controlled AWS-hosted Uvicorn process failure, systemd automatic recovery, health validation, and CloudWatch startup evidence

The incident reports document:

\- failure symptoms

\- investigation path

\- evidence collected

\- root cause

\- recovery steps

\- validation

\- lessons learned

**## Failure Scenario Roadmap**

The lab is designed to support controlled failure testing across multiple layers of the application and infrastructure stack.

Completed:

\- application process crash

\- nginx wrong upstream port / reverse proxy failure

\- automated EC2 replacement and bootstrap validation

\- AWS application process failure with automatic recovery

\- centralized systemd failure detection and CloudWatch alarming

Next planned scenarios:

1\. Filesystem permission failure

2\. Database dependency failure

3\. Network or security-group failure

4\. DNS failure

5\. CPU resource exhaustion

6\. Disk exhaustion

7\. Bad deployment

8\. Pipeline failure

9\. Terraform configuration drift

**## Security Notes**

Current AWS security practices include:

\- Uvicorn listens only on \`127.0.0.1:8000\`

\- nginx is the public-facing application entry point

\- only TCP port \`80\` is permitted inbound through the application security group

\- SSH port \`22\` is not publicly exposed

\- administrative access uses AWS Systems Manager Session Manager

\- EC2 permissions are provided through an IAM instance role

\- Instance Metadata Service v2 is required

\- Terraform state is stored in a private S3 bucket

\- S3 public access is blocked

\- S3 state versioning is enabled

\- Terraform state is encrypted at rest

\- Terraform state locking is enabled

\- credentials are not committed to the repository

\- local Terraform state files are excluded from Git

\- Python virtual environments are excluded from Git

The current public application endpoint uses HTTP. HTTPS/TLS is a planned improvement.

**## Future Improvements**

Planned improvements include:

\- add CloudWatch alarm notification delivery

\- add filesystem permission failure testing

\- add database dependency failure testing

\- add resource exhaustion testing

\- add bad-deployment rollback testing

\- add Terraform drift testing

\- add automated infrastructure validation

\- add HTTPS/TLS

\- add stable DNS

\- expand operational runbooks

\- expand incident reports

**## Status**

\`\`\`text

Local homelab deployment: Working

FastAPI application: Working

FastAPI health endpoint: Working

FastAPI version endpoint: Working

pytest tests: Passing

GitHub Actions CI: Working

systemd service: Working

Automatic restart: Validated

nginx reverse proxy: Working

Application crash scenario: Validated

nginx upstream failure scenario: Validated

Application crash runbook: Created

nginx failure runbook: Created

Application crash incident report: Created

nginx incident report: Created

AWS application process failure test: Validated

AWS systemd automatic recovery: Validated

AWS post-recovery health check: Validated

CloudWatch application restart evidence: Validated

CloudWatch systemd failure/recovery evidence: Validated

AWS VPC infrastructure: Working

Amazon Linux 2023 EC2 deployment: Working

Terraform infrastructure: Working

Automated EC2 bootstrap: Validated

AWS Systems Manager access: Working

Public SSH exposure: Disabled

CloudWatch Agent: Working

CloudWatch application logging: Working

CloudWatch nginx logging: Working

CloudWatch systemd lifecycle logging: Working

CloudWatch systemd failure metric filter: Working

CloudWatch systemd failure alarm: Validated

CloudWatch CPU alarm: Working

S3 Terraform backend: Working

Terraform state versioning: Enabled

Terraform state encryption: Enabled

Terraform state locking: Working

Terraform monitoring resources: Applied

Terraform full-plan reconciliation: Pending after bootstrap monitoring change

Next reliability scenario: Filesystem permission failure

\`\`\`
