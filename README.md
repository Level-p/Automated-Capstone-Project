# Automated Capstone Project with Terraform

**Author:** Onoja Steven  
**Date:** 13th December 2025

## Project Overview

This project demonstrates the design and implementation of a **highly available, highly scalable, and secure cloud environment** for deploying an image sharing application on AWS.

The infrastructure leverages **Infrastructure as Code (IaC)** with Terraform to automate the provisioning of AWS resources across multiple availability zones, ensuring **99.99% uptime** and automatic scaling capabilities.

## Key Features

- **High Availability**: Multi-AZ deployment across 2 availability zones
- **Scalability**: Auto-scaling groups that dynamically adjust capacity based on CPU utilization
- **Security**: 
  - VPC with public and private subnets
  - NAT Gateway for private subnet protection
  - AWS Secrets Manager for credential management
  - Checkov security scanning for infrastructure compliance
- **Performance**: CloudFront CDN distribution for cached image delivery
- **Monitoring**: CloudWatch metrics, alarms, and SNS notifications
- **Database**: Amazon RDS with automatic daily synchronization

## Architecture Highlights

- **2 Availability Zones** for disaster recovery
- **4 Subnets** (2 public, 2 private) for network isolation
- **Application Load Balancer** for traffic distribution
- **Auto-scaling Group** for dynamic capacity management
- **S3 Buckets** for application code, media files, and logs
- **CloudFront Distribution** for edge location caching
- **Route 53** for DNS management
- **CloudWatch Alarms** for proactive monitoring

## Project Objectives

1. ✅ Create Terraform infrastructure code
2. ✅ Configure cloud metric alarms and monitoring
3. ✅ Set up SNS, Secrets Manager, and S3 bucket policies
4. ✅ Deploy WordPress image sharing application
5. ✅ Validate auto-scaling and monitoring systems

## Full Documentation

For comprehensive project details, architecture diagrams, step-by-step implementation guide, and screenshots, **[download the full documentation](./Steven_automated_capstone.docx)** from this repository.

---

*This project showcases Infrastructure as Code best practices using Terraform, AWS cloud services, and security scanning tools to create a production-ready application environment.*
