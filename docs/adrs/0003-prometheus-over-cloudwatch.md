# ADR-0003: Self-Hosted Prometheus + Grafana Alongside CloudWatch

## Status
Accepted

## Context
Leadership's ask was blunt: a dashboard that tells the on-call engineer what's wrong before a customer complains. That requirement doesn't just mean "have metrics somewhere", it means metrics with enough resolution and the right alerting rules to catch a problem in the window between it starting and a customer noticing.

AWS gives this to you for free at the infrastructure layer: CloudWatch already collects EC2, ALB, and ASG metrics with zero setup, and SNS can turn an alarm into a page. The honest question was whether that's actually enough, or whether the platform needs its own metrics stack.

Two gaps showed up. First, CloudWatch's default EC2 metrics don't include memory or disk usage without installing the CloudWatch Agent anyway, so "zero setup" is a bit of a myth the moment you need anything beyond CPU and network. Second, and more importantly, CloudWatch has no visibility inside the application at all: request latency percentiles, error rates by endpoint, Gunicorn worker saturation, none of that exists unless something inside the app or the container exposes it. CloudWatch can tell you the instance is up; it can't tell you the app on it is slow.

The two options evaluated were: (1) go all-in on CloudWatch, installing the CloudWatch Agent for host-level metrics and pushing custom application metrics via the CloudWatch API, or (2) run Prometheus and Grafana self-hosted, scraping node_exporter for host metrics and instrumenting the Flask app directly, with Alertmanager handling routing to Slack.

## Decision
Run both, each for what it's good at, rather than picking one exclusively.

Prometheus + node_exporter + Grafana + Alertmanager handle everything close to the application: host-level metrics via node_exporter, and application-level metrics (request rate, latency, error rate) scraped directly from Flask/Gunicorn. Grafana is the dashboard the on-call engineer actually looks at day-to-day. Alertmanager routes threshold breaches to Slack.

CloudWatch stays in place for what only AWS can see: ALB-level metrics (target health, 5xx counts at the load balancer), NAT Gateway metrics, and ASG lifecycle events. SNS remains the channel for anything tied to AWS-native alarms, particularly ones that need to trigger infrastructure-level automation rather than just notify a human.

The two aren't merged into one pane by default — that's a deliberate simplification for this project's scope, not an oversight. In a larger team this would likely get unified via a CloudWatch exporter feeding Prometheus, or Grafana's CloudWatch data source plugin. The rationale below covers the tradeoff at each side, which is the part that matters for explaining this decision, not the plumbing to merge them.

## Consequences

**What this buys us:**
- Application-level observability that CloudWatch genuinely cannot provide out of the box, per-endpoint latency, error rate, Gunicorn worker state, visible before it becomes a customer-facing symptom, which was the actual requirement.
- No per-metric cost as instrumentation grows. Prometheus scraping is limited by the instance running it, not by a per-custom-metric bill, which matters once you start instrumenting every endpoint and background job.
- A genuine second skill demonstrated, not just AWS-native tooling, running and reasoning about a metrics stack you operate yourself, including its failure modes, is a materially different (and more transferable) skill than reading a managed dashboard.
- Redundancy at the infrastructure layer: if the Prometheus instance itself goes down, CloudWatch alarms on ASG/ALB health still function as a baseline safety net.

**What it costs us:**
- Prometheus itself is now infrastructure that has to be run, patched, and, this is the sharp edge, monitored for its own availability. A metrics stack that silently stops scraping is worse than no metrics stack, because it creates false confidence that everything's fine.
- Two systems means two places to check during an incident until dashboards are cross-linked, and two alerting paths (Alertmanager → Slack, SNS → wherever that's wired) that both need to stay correctly configured or an alert quietly goes nowhere.
- No built-in long-term storage or high availability for Prometheus in this setup, it's a single instance with local storage. A disk failure loses metric history, and there's no federation or remote-write to external storage configured. Acceptable for a portfolio project; a real production deployment would need Thanos, Cortex, or Amazon Managed Prometheus to close that gap.
- Someone has to own writing and tuning the alerting rules themselves, Prometheus doesn't come with sensible defaults for "what counts as an incident" the way some managed tools do. Bad thresholds mean either alert fatigue or missed incidents, and that tuning is ongoing work, not a one-time setup task.