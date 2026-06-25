# DNS Setup for Stargate

This guide covers all DNS records required for a working Stargate deployment. Configure these records **before** installing Stargate or immediately after, depending on the record type.

Throughout this guide:

- `<STARGATE_IP>` - your Stargate server's public static IP address (`SERVER_STATIC_IP` in `customer-config.sh`)
- `<MAIL_HOSTNAME>` - the FQDN of the Stargate relay (e.g. `mail.example.ch`; configured via the dashboard's `/mail` page)
- `<YOUR_DOMAIN>` - your mail domain (e.g. `example.ch`; configured via the dashboard's `/mail` page)

---

## Record Summary

| Record | Name | Value | Required | When |
|--------|------|-------|----------|------|
| [A](#a-record) | `<MAIL_HOSTNAME>` | `<STARGATE_IP>` | Yes | Before install |
| [MX](#mx-records) | `<YOUR_DOMAIN>` | `<MAIL_HOSTNAME>` (priority 15) | Yes | Before install |
| [SPF](#spf-record) | `<YOUR_DOMAIN>` | `ip4:<STARGATE_IP>` added to TXT | Yes | Before install |
| [PTR](#ptr-reverse-dns) | `<STARGATE_IP>` | `<MAIL_HOSTNAME>` | Recommended | Before install |
| [DMARC](#dmarc-record) | `_dmarc.<YOUR_DOMAIN>` | `v=DMARC1; p=none; ...` | Recommended | After install |
| [DKIM](#dkim-records) | `selector._domainkey.<YOUR_DOMAIN>` | From M365/provider | Recommended | After install |

For multi-domain deployments, repeat the MX, SPF, DMARC, and DKIM records for each domain listed in `MAIL_DOMAINS`.

---

## Required Records

### A Record

Create an A record pointing the Stargate mail hostname to the server's public IP:

```plain
<MAIL_HOSTNAME>.    A    <STARGATE_IP>
```

Example:

```plain
mail.example.ch.    A    128.140.117.200
```

If the Stargate has an IPv6 address, add an AAAA record as well:

```plain
mail.example.ch.    AAAA    2a01:4f8:c012:1234::1
```

**Why**: External mail servers connect to this hostname to deliver mail. Without the A record, the MX record below is unresolvable.

### MX Records

Add an MX record for the Stargate with a **higher priority** (lower number) than the existing mail server. This ensures inbound mail reaches the Stargate first for S/MIME processing before being forwarded to Exchange or your mail platform.

```plain
<YOUR_DOMAIN>.    MX    15    <MAIL_HOSTNAME>.
```

Keep the existing Exchange / mail server MX record at a lower priority (higher number):

```plain
<YOUR_DOMAIN>.    MX    20    <YOUR_DOMAIN>.mail.protection.outlook.com.
```

Example (complete MX set):

```plain
example.ch.    MX    15    mail.example.ch.
example.ch.    MX    20    example-ch.mail.protection.outlook.com.
```

!!! info
    The lower MX number means higher priority. Stargate at priority 15 receives mail before Exchange Online at priority 20.

**Why**: The Stargate intercepts inbound mail, processes S/MIME, then forwards to the next MX (Exchange). The second MX record is also used by Stalwart to know where to relay processed mail.

**Important**: If the Stargate is the **only** MX record for a domain, Stalwart will filter out its own hostname and have no delivery target. Always keep a second MX pointing to your actual mail server.

### SPF Record

Add the Stargate server IP **and the HIN sealer IP** to your domain's SPF record so outbound mail relayed through it passes SPF checks at the recipient's end.

**If you use M365 / Exchange Online:**

```plain
<YOUR_DOMAIN>.    TXT    "v=spf1 ip4:<STARGATE_IP> ip4:<HIN_SEALER_IP> include:spf.protection.outlook.com -all"
```

**If you do not use M365 / Google Workspace:**

```plain
<YOUR_DOMAIN>.    TXT    "v=spf1 ip4:<STARGATE_IP> ip4:<HIN_SEALER_IP> -all"
```

Example:

```plain
example.ch.    TXT    "v=spf1 ip4:128.140.117.200 ip4:193.247.208.66 include:spf.protection.outlook.com -all"
```

!!! question "Why the HIN sealer IP is required"
    When the Stargate produces a SEAL'd (encrypted) message for a non-HIN recipient, the final outbound hop to the recipient is the **HIN sealer**, not your Stargate or M365. Without the sealer IP in your SPF record, every SEAL'd outbound message will fail SPF at the recipient and - because there is no DKIM signature on the SEAL'd payload - DMARC will fail too. Strict-DMARC recipients (Gmail, Outlook with `p=reject` enforcement, Proofpoint) will reject or junk the message.

    Sealer IPs to add in SPF:

    | Environment | Sealer host | IP to add to SPF |
    |-------------|-------------|------------------|
    | HIN Test (alpha/beta) | `mx3.hintest.ch` | `193.247.208.66` |
    | HIN Production | TBD - request canonical list from HIN before go-live | TBD |

    If HIN publishes more than one sealer host (e.g. `mx1`, `mx2`, `mx3`), include **all** their IPs. Resolve them with `dig +short mx hintest.ch` followed by `dig +short A <each-mx>`. Until you have the full list, leave the SPF policy at `~all` (softfail) instead of `-all` (hardfail) so that legitimate SEAL mail through any unlisted sealer IP is not outright rejected.

!!! warning "SPF lookup limit"
    The total `include:` chain in an SPF record must stay under **10 DNS lookups**. Adding `ip4:` entries does not count toward this limit. Check your count with [MXToolbox SPF lookup](https://mxtoolbox.com/spf.aspx).

**How the Stargate uses SPF**: The mtaconf daemon resolves each domain's SPF record to auto-populate the list of IPs allowed to relay through the Stargate without authentication. This is how Microsoft 365 outbound IPs get whitelisted automatically - they appear in the `include:spf.protection.outlook.com` chain.

---

## Recommended Records

### PTR (Reverse DNS)

Configure the reverse DNS (PTR) record for the Stargate IP to match `<MAIL_HOSTNAME>`:

```plain
200.117.140.128.in-addr.arpa.    PTR    mail.example.ch.
```

This is configured at your **hosting provider** (Hetzner, Azure, AWS, etc.), not in your domain registrar's DNS panel. Most providers have a "Reverse DNS" or "rDNS" setting in the server/IP management page.

**Why**: Many receiving mail servers (including Gmail and Outlook) check that the connecting IP's PTR record resolves to a hostname, and that hostname resolves back to the same IP (forward-confirmed reverse DNS / FCrDNS). A missing or mismatched PTR is a strong spam signal and can cause delivery failures.

### DMARC Record

Publish a DMARC policy for each sending domain. Start with `p=none` (monitoring only), then tighten after confirming alignment:

```plain
_dmarc.<YOUR_DOMAIN>.    TXT    "v=DMARC1; p=none; rua=mailto:postmaster@<YOUR_DOMAIN>"
```

Example:

```plain
_dmarc.example.ch.    TXT    "v=DMARC1; p=none; rua=mailto:postmaster@example.ch"
```

Once DMARC aggregate reports confirm that SPF and/or DKIM pass consistently, tighten the policy:

1. `p=none` - monitoring only (start here)
2. `p=quarantine` - suspicious mail goes to spam
3. `p=reject` - unauthorized mail is rejected

**Why**: DMARC ties SPF and DKIM together and tells recipients what to do with mail that fails both. Even `p=none` is enough to clear Outlook's "we can't verify this sender" banner, as long as SPF passes.

Check your DMARC record: [MXToolbox DMARC lookup](https://mxtoolbox.com/dmarc.aspx)

### DKIM Records

If your domain is an accepted domain in M365 or Google Workspace, enable DKIM signing in the admin centre and publish the CNAME records as instructed:

**M365 example:**

```plain
selector1._domainkey.<YOUR_DOMAIN>.    CNAME    selector1-<YOUR_DOMAIN_DASHED>._domainkey.<TENANT>.onmicrosoft.com.
selector2._domainkey.<YOUR_DOMAIN>.    CNAME    selector2-<YOUR_DOMAIN_DASHED>._domainkey.<TENANT>.onmicrosoft.com.
```

!!! note
    Publishing the CNAME records alone is not enough - DKIM signing must also be **enabled** in the M365 admin centre (Defender portal > Email authentication > DKIM).

**Why**: DKIM proves the message body was not tampered with in transit. When combined with SPF and DMARC, it provides the strongest sender authentication.

---

## Multi-Domain Setup

For deployments handling multiple mail domains (configured via the dashboard's `/mail` page), each domain needs its own set of DNS records.

### Per-Domain Records

For each configured domain:

| Record | Required |
|--------|----------|
| MX pointing to `<MAIL_HOSTNAME>` | Yes |
| SPF including `ip4:<STARGATE_IP>` | Yes |
| DMARC (`_dmarc.<domain>`) | Recommended |
| DKIM (from your mail provider) | Recommended |

The A record and PTR record are shared (they point to the Stargate server, not to individual domains).

### Per-Domain Mail Routing

Each domain's MX records tell the Stargate where to deliver processed mail. If different domains use different Exchange servers:

```plain
domain1.ch    MX    15    mail.domain1.ch.
domain1.ch    MX    20    exchange1.domain1.ch.

domain2.ch    MX    15    mail.domain2.ch.
domain2.ch    MX    20    exchange2.domain2.ch.
```

Alternatively, configure explicit per-domain relay targets via the dashboard's `/mail` page (relay host field per domain) to override MX-based routing.

---

## Verification

After configuring all records, verify them:

```bash
# A record
host <MAIL_HOSTNAME>
# Expected: <MAIL_HOSTNAME> has address <STARGATE_IP>

# MX records
host -t mx <YOUR_DOMAIN>
# Expected: Both Stargate and Exchange MX records listed

# SPF record
host -t txt <YOUR_DOMAIN> | grep v=spf1
# Expected: SPF record includes ip4:<STARGATE_IP>

# PTR (reverse DNS)
host <STARGATE_IP>
# Expected: <STARGATE_IP> → <MAIL_HOSTNAME>

# Forward-confirmed reverse DNS (FCrDNS)
host $(host <STARGATE_IP> | awk '{print $NF}' | sed 's/\.$//')
# Expected: resolves back to <STARGATE_IP>

# DMARC
host -t txt _dmarc.<YOUR_DOMAIN>
# Expected: v=DMARC1; p=...

# DKIM (M365)
host -t cname selector1._domainkey.<YOUR_DOMAIN>
# Expected: CNAME to your tenant's onmicrosoft.com
```

Example output:

```shell
$ host mail.example.ch
mail.example.ch has address 128.140.117.200

$ host -t mx example.ch
example.ch mail is handled by 15 mail.example.ch.
example.ch mail is handled by 20 example-ch.mail.protection.outlook.com.

$ host -t txt example.ch | grep v=spf1
example.ch descriptive text "v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all"

$ host 128.140.117.200
200.117.140.128.in-addr.arpa domain name pointer mail.example.ch.

$ host -t txt _dmarc.example.ch
_dmarc.example.ch descriptive text "v=DMARC1; p=none; rua=mailto:postmaster@example.ch"
```

Online tools:

- [MXToolbox MX Lookup](https://mxtoolbox.com/MXLookup.aspx)
- [MXToolbox SPF Check](https://mxtoolbox.com/spf.aspx) (includes lookup count)
- [MXToolbox DMARC Check](https://mxtoolbox.com/dmarc.aspx)
- [Mail-Tester](https://www.mail-tester.com/) (send a test mail to get a deliverability score)

---

## Troubleshooting

### "Client host rejected: Access denied" (554 5.7.1)

Stalwart is rejecting the sending server because its IP is not in the allowed relay list. This usually means:

- The SPF record for your domain does not include the sending server's IP range
- The mail configuration has not been reloaded since the SPF record was updated

Reload the mail configuration via the dashboard's `/mail` page (submit the config again), or restart the container: `docker compose restart stalwart`

### Mail flagged as spam / "can't verify sender"

- SPF is missing or does not include the Stargate IP - add `ip4:<STARGATE_IP>` to your SPF record
- DMARC is not published - add at least `v=DMARC1; p=none`
- PTR record is missing or mismatched - configure reverse DNS at your hosting provider
- DKIM is not enabled in your M365/provider tenant

### MX lookup returns only the Stargate

If the Stargate is the only MX for a domain, Stalwart filters out its own hostname and has no relay target. Add a second MX record pointing to your mail server:

```plain
example.ch.    MX    15    mail.example.ch.          ← Stargate (inbound)
example.ch.    MX    20    example-ch.mail.protection.outlook.com.  ← Exchange (relay target)
```

### SPF lookup count exceeded (> 10)

Each `include:` in the SPF record triggers additional DNS lookups. The total chain must stay under 10. Solutions:

- Use `ip4:` / `ip6:` entries instead of `include:` where possible (they do not count)
- Flatten nested includes using a tool like [SPF Flattener](https://dmarcly.com/tools/spf-record-flattener)
- Remove unused `include:` entries from old providers

### Port 25 blocked by hosting provider

Some cloud providers (Azure, certain Hetzner plans) block outbound port 25 by default. Check with your provider and request an exception. This affects both inbound delivery (external servers connecting to your Stargate) and outbound relay (Stargate delivering to MX targets).
