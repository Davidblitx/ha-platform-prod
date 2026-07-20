# ADR-0001: Replace SSH Access with AWS SSM Session Manager

## Status
Accepted

## Context
The previous iteration of this platform (prod-web-server) used a standard bastion-less SSH setup: port 22 open on the instance security group, hardened with key-based auth and Fail2Ban to slow down brute-force attempts. That worked, but it left a permanent attack surface, port 22 was reachable from the internet (or at minimum from a defined CIDR block), and every engineer who needed access required a distributed SSH key that had to be provisioned, rotated, and eventually revoked.

As this project moved to a private-subnet ASG design, the SSH problem got worse, not better. A bastion host would have solved reachability, but it introduces its own security group, its own patching burden, and a second machine that itself becomes a target. It also does nothing to solve the audit problem: standard SSH sessions don't produce a centralized, queryable log of who ran what commands and when, something that matters the moment there's an incident and you need to reconstruct what changed.

The two options evaluated were: (1) keep SSH but route it through a bastion in the public subnet, or (2) drop SSH entirely and use AWS Systems Manager Session Manager.

## Decision
Use AWS SSM Session Manager for all instance access. No SSH keys, no bastion host, and no inbound rule for port 22 anywhere in the security groups, inbound access to the instances is limited to ALB traffic on the application port.

Each EC2 instance is launched with an IAM instance profile that grants the minimum permissions needed for the SSM agent to register with the Systems Manager service (AmazonSSMManagedInstanceCore), and the SSM agent is baked into the AMI/bootstrap so it's running before the instance ever joins the ASG. Access is then granted purely through IAM policy on the human side, engineers get ssm:StartSession permission scoped to instances tagged for this project, not a shared key.

## Consequences
**What this buys us:**

- Zero open inbound management ports on any instance, in any subnet. The attack surface for credential-stuffing or brute-force SSH attempts is eliminated outright, not just slowed down (Fail2Ban was mitigation; this is removal).
- Every session is logged centrally — who connected, when, and (if configured) every command run — without relying on individual instances to forward auth logs somewhere.
- Access control moves to IAM, which means revoking someone's access is an IAM policy change, not a key rotation across every instance they had access to.
- No bastion host to patch, monitor, or pay for.

**What it costs us:**

- Hard dependency on the SSM agent being present and healthy on every instance. If the agent fails to start, or the instance can't reach the SSM endpoints (either directly or via VPC endpoint / NAT), that instance becomes unreachable through the normal path — there's no SSH fallback by design. This is a real single point of failure for "how do I get onto this box" and it needs to be caught by health checks, not discovered during an incident.
- Every instance needs the IAM instance profile attached at launch time. If the Terraform compute module ever gets refactored and someone forgets to attach the role, that instance silently loses manageability — it'll pass an ALB health check and still be inaccessible for debugging.
- Requires outbound connectivity to the SSM/EC2 messages endpoints. In this design that means either the NAT Gateway is healthy (see ADR-0002) or VPC interface endpoints are provisioned — one more thing that has to stay up for access to work at all.
- Team members without AWS console/CLI access effectively have no way in. This is a feature for security, but it's a real onboarding cost compared to "here's an SSH key."