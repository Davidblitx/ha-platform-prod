# Postmortem: Nginx Downtime Following OS Patching

## Incident Summary
During a routine OS patching cycle on the (then single) production EC2 instance, security updates were applied using `apt upgrade`. The patch run touched a dependency that Nginx relies on, and as part of standard practice the process should have ended with a service restart to make sure Nginx picked up the new libraries and reloaded cleanly. That restart step was skipped. Nginx kept running on stale library references until the next request came in and the worker process failed to serve it. The site was down for end users until someone noticed and manually restarted the service.

## Timeline
- **T+0:00** - Scheduled OS patching begins on the production instance via SSH. Standard `apt update && apt upgrade` run.
- **T+0:04** - Patches applied successfully, including updates to packages Nginx links against. No service restart performed as part of the patch script, since it was a manual, ad hoc run rather than a scripted procedure.
- **T+0:04 to T+0:41** - Nginx continues serving traffic using its already-loaded (now stale) library state. No immediate symptoms.
- **T+0:41** - Nginx worker process encounters an error tied to the mismatched library state and fails to handle incoming connections correctly. Requests start timing out or returning connection errors.
- **T+0:47** - First user-facing reports of the site being unreachable.
- **T+1:15** - On-call engineer investigates, confirms the instance is running (EC2 status checks green) but Nginx is not responding on port 80.
- **T+1:22** - Manual `systemctl restart nginx` performed. Service comes back up immediately.
- **T+1:23** - Site confirmed reachable again. Incident closed.

Total time from patch to detection: 47 minutes. Total time from first user report to resolution: 35 minutes. Total outage window: roughly 42 minutes of degraded or total unavailability.

## Root Cause
Patching and service restart were treated as two separate, manually-remembered steps instead of one atomic operation. There was nothing in the process that verified Nginx was actually healthy after the patch ran, and there was no automated check anywhere in the stack that would notice a running-but-unresponsive Nginx process. The instance itself looked completely healthy the entire time (EC2 status checks only confirm the instance is up, not that the application on it is serving traffic), so there was no signal at all until a human either checked manually or a customer complained.

The deeper root cause isn't "someone forgot a command." It's that the architecture at the time had no independent verification of application health separate from instance health, and no automatic recovery path if the application layer failed while the instance layer stayed up.

## Impact
Single point of failure meant the entire outage was total, not partial. Every request during the ~42 minute window failed. Because this was a single EC2 instance with no load balancer in front of it, there was no way to gradually detect degradation or drain traffic away from a failing node. It was either fully up or fully down, and there was no automated mechanism to tell the difference until a human looked.

## Resolution
Immediate fix was a manual service restart, which resolved the symptom in under a minute once someone was actually looking at the box. That's the uncomfortable part of this incident: the fix itself was trivial. The entire 42 minutes of impact came from the gap between the patch running and a human noticing, not from any difficulty fixing the problem once found.

## Prevention (what this architecture now does differently)
This is the actual point of the redesign, and it's why this incident can't repeat in the same form on the current platform.

The instance is no longer directly internet-facing and is no longer a single point of failure. It sits behind an Application Load Balancer, and the ALB performs its own health checks against the application, not just against the instance. If Nginx stops responding on its health check path for the configured number of consecutive checks, the ALB marks that target unhealthy and stops routing traffic to it immediately, well before it would exhaust a human's patience waiting for a page to load.

Because the instance lives in an Auto Scaling Group rather than existing as a standalone box, an instance that fails its health check for long enough gets terminated and replaced automatically. The ASG launches a fresh instance from the current launch template, which pulls the current container image and bootstraps itself the same way every other instance does. Nobody restarts Nginx by hand. The unhealthy instance is simply removed from service and replaced, and because the ASG maintains a minimum of two instances across two AZs, the other instance keeps serving traffic the entire time this is happening.

On the observability side, this would now surface long before the ALB even finishes its health check cycle. node_exporter and the application-level Prometheus scrape would show the instance's Nginx process state and request success rate dropping, and an Alertmanager rule tuned for elevated error rate or a scrape target going quiet would fire to Slack. The on-call engineer would know something was wrong from a metrics dashboard, not from a customer support ticket.

Patching itself also changes. OS patching against a live, hand-maintained instance is no longer the model. New AMIs or container images are built and rolled out through the ASG's instance refresh, meaning "patch and restart" stops being two manual steps a person has to remember and becomes a single deploy that naturally replaces old instances with fully-provisioned new ones. There's no window where an instance is running with half-updated state, because it's never patched in place at all.
