# AGENTS.md

## Purpose

This repository is an AWS learning and portfolio repository for preparing for an AWS security and network improvement project at a bank.

The expected project work is not application development as the main focus. The focus is checking existing AWS settings, confirming security controls, applying approved configuration changes, testing after changes, preparing procedure documents, and reporting results.

Codex should treat work in this repository as practical preparation for real AWS operations, not only as certification study.

## Communication

- Respond in Japanese by default.
- Keep explanations practical and suitable for job preparation.
- When creating documents, write them so the user can explain the work in an interview or project meeting.
- Prefer clear, calm, hands-on explanations over abstract theory.
- When giving AWS guidance, distinguish between lab assumptions and real project assumptions.

## Project Context

The assumed project is:

- System: bank transfer and electronic storage system.
- Work area: AWS security, AWS network optimization, and improvement.
- Period: July to September, with possible extension.
- Role: AWS cloud engineer expected to work independently.
- Work style: remote is possible, but onsite may happen until the user gets used to the project.
- Communication: mainly Teams.
- Direct customer coordination may be limited, but communication with NTT Data-side members may happen.
- Investigation using the internet is expected to be possible to some extent.
- AI usage may be available in the project environment.

## Expected Work

When preparing scripts, references, or procedure documents, assume the user may need to perform or explain the following:

- Check AWS configurations.
- Check security control status.
- Apply approved configuration changes to already investigated items.
- Test after configuration changes.
- Create procedure documents.
- Create rollback procedures.
- Prepare evidence.
- Report results to stakeholders.

The user is expected to act as an AWS knowledgeable person and proceed with actual work independently, while receiving support from managers or team members when necessary.

## Priority AWS Topics

Give high priority to the following topics:

- S3
- S3 bucket policies
- CloudTrail
- CloudWatch
- GuardDuty
- Detection of AWS Management Console login without MFA
- VPC
- EC2
- RDS
- Lambda
- AWS security settings
- AWS network settings

Especially important areas:

- S3 security settings
- Impact investigation for S3 bucket policy changes
- CloudTrail log collection and event investigation
- CloudWatch Logs and Alarm integration
- GuardDuty finding investigation
- MFA-related detection, especially console login without MFA
- Change procedure documents and rollback procedure documents

## Portfolio Strengths To Preserve

When creating docs or scripts, preserve and reinforce these strengths because they were valued in the interview:

- AWS environments are built with AWS CLI and shell scripts.
- The repository contains architecture diagrams and design documents.
- The lab environment can be cleaned up with self-made cleanup scripts.
- The user has actually built Bastion, private Web servers, ALB, RDS, S3, Route 53, ACM, SES, and ElastiCache.
- GuardDuty verification is being added.
- The user has Linux, network, firewall, and security product experience.

## Documentation Rules

For Markdown files related to AWS operations, include the following whenever relevant:

- Purpose
- Assumptions
- Target resources
- Before-change checks
- Implementation steps
- Impact scope
- After-change checks
- Test method
- Rollback method
- Security notes
- Evidence to capture
- Points that can be explained in the project
- Points connected to AWS certification study
- Common errors and troubleshooting
- Teams-style report examples when useful

Use the existing repository style:

- Use Japanese headings and explanations.
- Use AWS CLI examples.
- Prefer `--profile learning` and `--region ap-northeast-1` for lab examples unless another value is specified.
- Save command evidence to an `evidence/` directory when the document is about real operations.
- Use tables for checklists and comparison points.
- Include expected values and how to interpret command output.
- Update `README.md` links when adding important reference documents.

## AWS CLI And Evidence

When writing AWS CLI examples:

- Start with `aws sts get-caller-identity`.
- Clearly state the target account, profile, and region.
- Prefer JSON output for evidence files.
- Use table output for human-readable checks.
- Include before and after evidence examples.
- Mention that timestamps may need UTC/JST conversion.
- Avoid storing secrets in evidence.
- Mention when evidence should be supplemented with AWS Management Console screenshots.

For real or production-like operations, always consider:

- Change approval
- Maintenance window
- Impact scope
- Rollback plan
- Evidence retention
- Stakeholder reporting

## Security Rules

Never write secrets into repository files.

Do not store:

- AWS access keys
- AWS secret access keys
- Session tokens
- DB passwords
- SMTP passwords
- Secret keys
- Private customer information

When a command may reveal sensitive data, warn the user and suggest masking or limiting output.

For security-related docs, consider:

- Least privilege
- Public access exposure
- Encryption
- Logging
- CloudTrail auditability
- IAM policy scope
- Resource policy scope
- Cross-account access
- External access paths
- Rollback and blast radius

## S3 And Bucket Policy Focus

S3 and bucket policy work is a core project theme.

When working on S3 documents or scripts, include:

- Public Access Block
- ACL / Object Ownership
- Bucket Policy
- Bucket encryption
- Versioning
- Server access logging or CloudTrail Data events
- Access Analyzer / public access checks when applicable
- Before and after policy comparison
- Impact on application, IAM Role, VPC Endpoint, CloudFront, ALB, Lambda, and cross-account access when relevant
- Rollback using saved pre-change policy

## CloudTrail / CloudWatch / GuardDuty Focus

For CloudTrail:

- Cover Trail, Event History, Event Selectors, Data events, S3 log delivery, CloudWatch Logs integration, and Event Data Store when relevant.
- For CloudTrail Lake, mention current service availability and check whether the target account already uses it.

For CloudWatch:

- Cover Log Groups, metric filters, alarms, dashboards, and evidence.
- Connect CloudTrail events to CloudWatch Logs when discussing detection.

For GuardDuty:

- Cover enablement status, findings, severity, affected resource, evidence, investigation flow, and reporting.
- Explain what action should be taken after a finding is confirmed.

For MFAなし管理コンソールログイン検知:

- Use CloudTrail `ConsoleLogin`.
- Check `additionalEventData.MFAUsed`.
- Explain CloudWatch Logs metric filter and alarm flow.
- Include test and evidence points.

## Network Focus

For VPC, EC2, RDS, Lambda, and network documents, include:

- VPC
- Subnet
- Route Table
- Internet Gateway
- NAT Gateway
- Security Group
- Network ACL
- VPC Endpoint
- ALB / Target Group
- RDS private connectivity
- Lambda VPC attachment when relevant
- VPC Flow Logs when relevant

Always explain impact in terms of connectivity:

- Source
- Destination
- Protocol
- Port
- Route
- Security Group
- NACL
- DNS

## Scripts

When creating or reviewing scripts:

- Use `set -euo pipefail` for Bash scripts unless there is a reason not to.
- Confirm caller identity before creating or deleting AWS resources.
- Use clear names and constants near the top.
- Make scripts rerunnable when possible.
- Handle missing resources gracefully for cleanup scripts.
- Avoid destructive operations without explicit confirmation.
- Include cleanup or rollback considerations for chargeable resources.
- Prefer AWS CLI commands that are understandable to the user over overly compact one-liners.

## Cost Awareness

This repository creates chargeable AWS resources.

When relevant, remind the user to clean up:

- NAT Gateway
- RDS
- ElastiCache
- ALB
- EC2
- CloudWatch Logs with long retention
- CloudTrail Data events
- S3 buckets with stored data

Do not create new chargeable resources unless the user explicitly asks or the task clearly requires it.

## Editing Rules

- Preserve existing file style and naming.
- Keep changes scoped to the user's request.
- Do not remove user changes unless explicitly asked.
- Use existing directories:
  - `scripts/` for AWS CLI scripts and CLI references.
  - `docs/` for design documents, case studies, templates, and architecture notes.
  - `ansible/` for Ansible-related work.
- When adding an important Markdown reference, consider adding it to `README.md`.

## Preferred Learning Flow

The current learning flow is:

1. Complete the AWS web application platform according to the `aws-reference` design.
2. Add S3 security confirmation procedures.
3. Add bucket policy change procedures.
4. Add CloudTrail enablement and log checks.
5. Add CloudWatch Logs integration.
6. Add GuardDuty enablement and finding investigation.
7. Add MFAなしログイン検知.
8. Add VPC Flow Logs.
9. Add Security Group / Route Table impact investigation templates.
10. Add change procedure and rollback templates.

When the user asks what to do next, recommend the next item in this flow unless a more urgent issue exists.

