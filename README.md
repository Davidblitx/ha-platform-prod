# High Availability Web Platform on AWS with Observability

The Scenario: My company's Flask app currently runs on one EC2 instance. It went down twice last month during traffic spikes, and once when someone patched the OS and forgot to restart Nginx. Leadership wants zero-downtime deploys, automatic recovery from instance failure, and a dashboard that tells the on-call engineer what's wrong before a customer complains. 

The Solution:
High-availability web platform on AWS built from first principles.
Multi-AZ VPC, containerized Flask/Gunicorn/Nginx stack, 
automated EC2 provisioning via bootstrap script.

**Status: In progress — Terraform and observability layer in development.**

## Stack
AWS (VPC, EC2, ALB, ASG, NAT, IAM, SSM), Docker, Flask, Gunicorn, Nginx, Bash

## Problem
Company Flask app on single EC2 went down twice during traffic spikes 
and once when Nginx wasn't restarted after an OS patch.

## Solution
Multi-AZ architecture with ALB for traffic distribution, ASG for 
self-healing, and automated bootstrap script eliminating manual provisioning.
