# Multi-Domain Scenarios and Recommendation

*MGW → HIN Gateway – Mail-Flow Architecture, Phased Rollout, and Rollback Plan*


## Phase 1 – Starting Point: Baseline (All Domains on MGW)

**Baseline state**

- All domains are routed through the MGW. Example: domain1.ch, domain2.ch, domain3.ch, un-domain1.ch, un-domain2.ch
- The HIN Gateway is deployed and prepared, but no live traffic is routed through it yet.
- DNS MX/SPF records still point to "Public IP A" (MGW), where the MGW is the front-facing gateway or the last MTA.

!!! info "Pre-flight checklist"
    - Establish a baseline for the current MGW capacity and mail-flow logs.
    - Validate HIN Gateway connectivity to Online Protect, Exchange Online, and the on-premises email server.
    - Align stakeholders on the migration schedule and communication plan.
    - Review firewall/port documentation ahead of Public IP B provisioning (Phase 2, step 1)

 <br> ![Start-Baseline](assets/multi-domain-scenario/Phase1-start-baseline.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Phase 2 – Migration: Gradual Domain-by-Domain Example

**Migration steps**

1. **Provision** HIN Gateway — assign `Public IP B` and update firewall rules (see network documentation for required ports)
2. **Create two connectors in Exchange Online—one** inbound and one outbound—pointing to the HIN Gateway.
3. **Add a mail-flow rule** that routes by domain: domain1.ch → HIN Gateway, all remaining domains stay on MGW
4. **Repeat the process gradually**, moving one additional domain at a time until all domains are routed through the HIN Gateway.

!!! danger "Roll-back (per domain)"
    - Point the affected domain's mail-flow rule back to MGW
    - Leave the Stargate connectors in place for the next attempt
    - **Keep an ordered change log** of every connector and rule modification. A rollback must apply these changes in reverse order.

!!! warning "Watch for customer-specific headers"
    Some domains rely on custom X-headers (routing, anti-spam allow-lists, compliance tags). Confirm that the HIN Gateway connectors preserve or replicate these headers before migrating a domain. Missing headers may result in incorrect routing or rejected emails.

![Phase 2 Migration - gradual, domain-by-domain](assets/multi-domain-scenario/Phase2-migration-domain-by-domain.png)

## Phase 3 Final - fully migrated to HIN Gateway

!!! success "End state"
    - All domains now flow through HIN Gateway
    - **MGW** carries no production traffic
    - DNS/SPF records now point to Public IP B where the HIN Gateway is the front-facing gateway or the last MTA.

!!! note "Clean-up checklist"
    - Remove the old MGW connectors and mail-flow rules
    - Decommission the MGW VM once monitoring confirms that it is receiving no traffic and that email flow is functioning correctly 
    - Release **Public IP A** if no longer required
    - Update runbooks and DNS documentation

![Phase 2 Migration - gradual, domain-by-domain](Phase3-final-fully-migrated.png)

## Migration strategy comparison

!!! tip "Recommended – Migrate All Domains at Once"
    - No additional Public IP required
    - No temporary connector or mail-flow-rule changes
    - Simple roll-back: power off Stargate, power the old MGW VM back on
    - Shortest cutover window — lowest chance of configuration drift

!!! note "Alternative – Gradual Domain-by-Domain Migration"
    - Lower blast radius per step — only one domain at risk at a time
    - Requires a second public IP address and temporary split-routing rules and connectors
    - Must handle customer-specific headers per domain
    - Roll-back requires replaying the exact change sequence in reverse

---

!!! warning
    Confirm the exact firewall ports and connector settings against the current network documentation before performing any installation steps.

!!! note
    See the specific notes in the [HIN Gateway Installation Guide](Installation-guide.md) regarding multi-domain migration.
