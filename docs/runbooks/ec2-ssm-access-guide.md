# Runbook: EC2 Access via SSM Session Manager

## Purpose
How to connect to a production instance, check its health, read logs, and restart services when something's alerting. No SSH is used anywhere in this stack.

## Prerequisites
- AWS CLI v2 installed and configured with credentials that have `ssm:StartSession` permission.
- Session Manager plugin for the AWS CLI installed:

```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo yum install -y session-manager-plugin.rpm
```
- Know which instance you need. List running instances for this project:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=ha-web-platform" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,PrivateIpAddress,State.Name]" \
  --output table
```

## Connecting to an instance
```bash
aws ssm start-session --target i-0c002335fe145070b
```

You'll land in a shell as `ssm-user`. Switch to root if needed:
```bash
sudo -i
```

To run a single command without opening an interactive session:
```bash
aws ssm send-command \
  --instance-ids i-0c002335fe145070b \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl status nginx"]' \
  --query "Command.CommandId" \
  --output text
```
Then fetch the output:
```bash
aws ssm get-command-invocation \
  --command-id 4d2978f0-ad7d-48e8-8680-f0cc05f9f2b6 \
  --instance-id i-0c002335fe145070b
```

## Reading application logs
Once connected via `start-session`:

Flask/Gunicorn logs (containerized app):
```bash
docker ps
docker logs --tail 200 -f 7971ff60c92f
```

Nginx access and error logs:
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

System logs:
```bash
sudo journalctl -xe
sudo journalctl -u nginx --since "1 hour ago"
```

## Checking service health
Nginx status:
```bash
sudo systemctl status nginx
```

Is Nginx actually listening on port 80?
```bash
sudo ss -tlnp | grep :80
```

Is the app container running and healthy?
```bash
docker ps --filter "name=ha-platform-app"
docker inspect --format='{{.State.Health.Status}}' 7971ff60c92f
```

Check what the ALB thinks of this instance:
```bash
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-west-1:234444451024:targetgroup/prod-app-tg/21f3629d5036b3d1
```

Local health check endpoint (same path the ALB hits):
```bash
curl -i http://localhost:80/health
```

Node-level metrics (CPU, memory, disk):
```bash
curl -s http://localhost:9100/metrics | head -50
```

## Restarting services
Restart Nginx:
```bash
sudo systemctl restart nginx
sudo systemctl status nginx
```

Restart the app container:
```bash
docker restart 7971ff60c92f
docker logs --tail 50 7971ff60c92f
```

If the instance itself is unhealthy and not recovering, don't keep troubleshooting in place. Terminate it and let the ASG replace it:
```bash
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id i-0c002335fe145070b \
  --should-decrement-desired-capacity false
```
This is often the fastest correct move. The ASG launches a replacement from the current launch template automatically.

## Escalation path
1. Check the Grafana dashboard first: request error rate, latency, and node health for all instances, not just the one alerting.
2. Check Slack `#alerts` for the Alertmanager notification that triggered this. It names the specific rule that fired and the instance/target involved.
3. If the fix is a restart (Nginx or the container) and it resolves the alert, done, log it in the incident channel with instance ID and timestamp.
4. If a restart doesn't resolve it within 5 minutes, terminate the instance per the command above and let the ASG replace it. Do not spend on-call time debugging a single bad instance when replacement is one command away.
5. If the issue is affecting multiple instances at once (not just one), this is not a single-instance problem, stop and escalate to the team lead immediately rather than replacing instances one by one.
6. If SSM connection itself fails ("TargetNotConnected" or similar), check NAT Gateway health first, this is the most common cause. See ADR-0002.
