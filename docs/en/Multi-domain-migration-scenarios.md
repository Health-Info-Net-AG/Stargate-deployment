# Multi-Domain Migration Scenario

*MGW → HIN Gateway - mail-flow architecture, phased rollout & roll-back plan*


## Phase 1  Start - Baseline (all domains on MGW)

**Baseline state**

- All domains route through **MGW** Example: domain1.ch, domain2.ch, domain3.ch, un-domain1.ch, un-domain2.ch
- HIN Gateway deployed preparation - no live traffic yet
- DNS MX / SPF records still resolve to **Public IP A** (MGW) - that's in case MGW is the front-facing traffic or the last MTA

!!! info "Pre-flight checklist"
    - Baseline current MGW capacity & mail-flow logs
    - Validate Stargate lab connectivity to Online Protect / Exchange Online / On-prem email server
    - Align stakeholders on migration schedule & communication plan
    - Review firewall/port documentation ahead of Public IP B provisioning (Phase 2, step 1)

 <br> ![Start-Baseline](assets/multi-domain-scenario/Phase1-start-baseline.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

## Phase 2 Migration - gradual, domain-by-domain example

**Migration steps**

1. **Provision** HIN Gateway — assign `Public IP B` and update firewall rules (see network documentation for required ports)
2. **Create two connectors** on Exchange Online — one Inbound, one Outbound — pointing to Stargate
3. **Add a mail-flow rule** that routes by domain: domain1.ch → HIN Gateway, all remaining domains stay on MGW
4. **Repeat gradually** — move one additional domain at a time until every domain is on HIN Gateway

!!! danger "Roll-back (per domain)"
    - Point the affected domain's mail-flow rule back to MGW
    - Leave the Stargate connectors in place for the next attempt
    - Keep a **change log** of every connector/rule edit, in order — roll-back must replay it in reverse

!!! warning "Watch for customer-specific headers"
    Some domains rely on custom X-headers (routing, anti-spam allow-lists, compliance tags). Confirm Stargate's connectors preserve/replicate these headers before cutting a domain over — missing headers can cause mis-routing or rejected mail.

![Phase 2 Migration - gradual, domain-by-domain](assets/multi-domain-scenario/Phase2-migration-domain-by-domain.png)

## Phase 3 Final - fully migrated to HIN Gateway

!!! success "End state"
    - All domains now flow through HIN Gateway
    - **MGW** carries no production traffic
    - DNS / SPF now point to **Public IP B** (that's in case HIN Gateway is the front-facing traffic or the last MTA )

!!! note "Clean-up checklist"
    - Remove the old MGW connectors and mail-flow rules
    - Decommission the MGW VM once monitoring confirms zero traffic and email flow is working properly 
    - Release **Public IP A** if no longer required
    - Update runbooks and DNS documentation

![Phase 2 Migration - gradual, domain-by-domain](Phase3-final-fully-migrated.png)

## Migration strategy comparison

!!! tip "Recommended — Move all domains at once"
    - No additional Public IP required
    - No temporary connector or mail-flow-rule changes
    - Simple roll-back: power off Stargate, power the old MGW VM back on
    - Shortest cutover window — lowest chance of configuration drift

!!! note "Alternative — gradual, domain-by-domain"
    - Lower blast radius per step — only one domain at risk at a time
    - Needs a second Public IP and temporary split rules/connectors
    - Must handle customer-specific headers per domain
    - Roll-back requires replaying the exact change sequence in reverse

---

!!! warning
    Confirm exact firewall ports, and connector settings against the current network documentation before executing any instalation steps.

!!! note
    See the specific remarks written in the [Domain Installation Guide](Installation-guide.md) about multi-domain migration.
