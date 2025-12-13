# Azure Production Landing Zone (Bicep)

A reusable, production-grade Azure landing zone scaffolded with Bicep. The design prioritizes security, governance, and operational guardrails for production workloads while keeping modules composable for reuse in different environments.

## Architecture Overview
- **Subscription scope** deployment that provisions resource groups for networking, identity, shared services, and application workloads.
- **Modular Bicep** structure under `modules/` for networking, identity (RBAC), security (Key Vault), logging, and policy/governance.
- **Network baseline** with a hub virtual network, segmented public/private subnets, and a private endpoint subnet with NSG protection.
- **Central operations** via a shared Log Analytics workspace and subscription-level activity log collection.

### Text-based Diagram
```
[Subscription]
├─ Resource Groups
│  ├─ <org>-<env>-net-rg     (VNet, NSGs, subnets)
│  ├─ <org>-<env>-id-rg      (RBAC custom roles)
│  ├─ <org>-<env>-shared-rg  (Key Vault, Log Analytics)
│  └─ <org>-<env>-apps-rg    (Workload landing zone)
│
├─ Policy Assignments (subscription scope)
│  ├─ Required tags: owner, environment, costCenter
│  ├─ Deny public IP creation
│  └─ Allowed regions only
│
└─ Diagnostic Settings
   ├─ Subscription activity logs → Log Analytics
   ├─ NSG flow/rule logs → Log Analytics
   └─ Key Vault audit logs → Log Analytics
```

## Security Model
- **Network security**: NSGs enforce least privilege. Public subnet only allows essential ingress (e.g., health probes); private subnet denies internet egress by default. Private endpoint subnet has endpoint policies enabled.
- **Identity**: Custom RBAC roles for Platform Admin, Application Operator, and Auditor. No owner-level permissions granted to applications.
- **Key Vault**: RBAC-enabled, public network access disabled, TLS-only, soft delete, and purge protection enabled. Optional private endpoint support.
- **Secrets**: No hard-coded secrets. Key Vault is the system of record with access enforced via RBAC.

## Governance Strategy
- **Azure Policy** ensures tagging standards, denies public IP creation, and restricts deployments to approved regions.
- **Activity Logs** are exported to the central Log Analytics workspace for auditability.
- **Diagnostics**: NSGs and Key Vault stream diagnostic logs to the shared workspace for security analytics.

## Operational Model
- **Separation of concerns** through dedicated resource groups and modules.
- **Idempotent IaC**: No portal/manual steps required. Modules can be reused across environments by changing parameters.
- **Naming conventions** enforced by the `orgPrefix` + `environment` pattern applied consistently across resources.

## Consuming the Landing Zone
1. Update parameters in `main.bicep` (e.g., `orgPrefix`, `environment`, `allowedRegions`, and principal object IDs for RBAC assignments).
2. Deploy at the subscription scope:
   ```bash
   az deployment sub create \
     --template-file main.bicep \
     --location <primary-region> \
     --parameters orgPrefix=<org> environment=<env> \
                  platformAdminObjectId=<objectId> \
                  appOperatorObjectId=<objectId> \
                  auditorObjectId=<objectId>
   ```
3. Application teams onboard workloads into `<org>-<env>-apps-rg`, peering to the hub VNet or using Private Endpoints as required.

## Module Breakdown
- `modules/networking/main.bicep` – VNet, segmented subnets, NSGs, and diagnostic settings.
- `modules/identity/main.bicep` – Custom RBAC role definitions and assignments.
- `modules/security/main.bicep` – Hardened Key Vault with optional private endpoint and diagnostics.
- `modules/logging/main.bicep` – Central Log Analytics workspace.
- `modules/policy/main.bicep` – Azure Policy definitions/assignments and activity log diagnostics.

## Production Defaults
- Deny-by-default posture for private subnet ingress and internet egress.
- Key Vault public access disabled and protected with soft-delete/purge protection.
- Mandatory tagging and region restrictions enforced at subscription level.
- Activity, NSG, and Key Vault diagnostics enabled out-of-the-box.
