# ADR-0002: Single NAT Gateway Instead of One Per Availability Zone

## Status
Accepted

## Context

The network module provisions a VPC spanning two availability zones (eu-west-1a and eu-west-1b), each with a public and private subnet, to satisfy the multi-AZ requirement for the ALB and the Auto Scaling Group. Instances in the private subnets have no public IP, by design, per ADR-0001, they're never directly internet-reachable, but they still need outbound internet access for OS package updates, pulling container images from ECR, and reaching the SSM endpoints that make Session Manager work at all.

The textbook highly-available pattern is one NAT Gateway per AZ, each private subnet routing outbound traffic through the NAT Gateway in its own AZ. That way, an AZ failure only takes down outbound connectivity for instances in that AZ, the other AZ keeps working independently, and there's no cross-AZ data transfer charge on the NAT path.

The problem is cost, and it's not a rounding error. Each NAT Gateway carries an hourly charge plus a per-GB data processing charge, so two NAT Gateways roughly double that fixed cost before a single byte of app traffic is served. This is a portfolio project simulating a real workload, not a production system with an SLA or a paying customer on the other end, the traffic volume doesn't come close to justifying the second gateway on availability grounds alone.

## Decision

Provision a single NAT Gateway in eu-west-1a. Both private subnets, 1a and 1b, route their outbound (0.0.0.0/0) traffic through this one NAT Gateway. The route tables for both private subnets point at the same NAT Gateway ID; there is no NAT Gateway in eu-west-1b.

The ALB and ASG remain genuinely multi-AZ for inbound traffic and instance placement, that redundancy isn't touched. This decision only collapses the outbound path.

## Consequences

What this buys us:

- Roughly half the NAT-related cost of the textbook design, which matters a lot more on a self-funded project than the marginal availability gain does.
- The inbound, request-serving path, the part that actually determines whether a customer's request succeeds, stays fully multi-AZ. The ALB can still route to healthy instances in either AZ.

What it costs us:

- eu-west-1a is now a single point of failure for outbound connectivity. If that AZ has an outage, or even just the NAT Gateway itself fails, private-subnet instances in eu-west-1b lose their route to the internet even though the AZ they're physically in is healthy. In practice this means: no OS updates, no new image pulls from ECR, and no reachability to the SSM endpoints for any instance whose route table points at that dead NAT Gateway.
- Concretely for this platform: an already-running instance in 1b keeps serving traffic through the ALB just fine during that outage, since inbound HTTPS doesn't touch the NAT Gateway at all. What breaks is anything requiring outbound access, a new instance in 1b trying to pull its container image at boot would fail to start, and nobody could SSM into any 1b instance to debug it, because SSM connectivity depends on that same broken outbound path.
- This is a decision that has an expiration date. If this system ever carries real production traffic with an actual availability target, the second NAT Gateway is one of the first things that should come back, the fix is a route table change plus one more resource, not a redesign, but it needs to be a conscious re-evaluation, not something quietly forgotten because "it's worked fine so far."
