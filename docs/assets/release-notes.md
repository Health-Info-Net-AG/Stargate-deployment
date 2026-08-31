## v0.6.0

*Released on 31 August 2026.*

This release adds multi-domain migration support, domain-level relay configuration, email authentication(such as DIKM and ARC) and improvements to installation, security and stability.

### What’s new and improved

- **Multi-domain setups:** Multiple domains can now be configured or migrated to a single HIN Gateway. The updated guidance covers complete and phased migrations, including rollback scenarios
- **Domain based configuration:** Relay configuration per domain is now available
- **Email authentication:** DKIM and ARC signing, as well as DKIM, ARC, SPF and DMARC verification, can now be configured for each domain. The required DNS records are shown directly in the HIN Gateway
- **Installation and migration:** Updated guidance now covers new installations, single-domain and multi-domain migrations, Exchange integration, mail routing, networking and TLS testing
- **Appliance migration:** A documented process is available for moving an existing Docker Compose installation to the image-based HIN Gateway appliance
- **Backup and restore:** Persistent data now uses a consistent location, with safer restore handling and warnings when backup and target versions differ
- **Diagnostics and security:** Health checks, logging and diagnostic collection have been improved. Installation and recovery scripts now provide better protection for credentials and backup data

### Fixes

- Improved first-time initialization of Vault and WireGuard settings
- Improved service startup on slower virtual machines
- Fixed edge cases affecting backup and restore operations
- Fixed inaccurate health-check results and configuration fallback handling

### Important information for appliance migrations

When moving an existing Docker Compose installation to the image-based appliance, follow the dedicated migration guide. Restoring a backup replaces all data on the target appliance. If its public IP address changes, HIN must update the central WireGuard registration.

## v0.5.3

*Released on 29 July 2026. Hotfix applied on 5 August 2026.*

This release improves email delivery, certificate handling, the dashboard and troubleshooting. There are no changes to SEAL.

### Hotfix, 5 August 2026

Fixed an issue in the certificate import process where the domain was not correctly linked to the corresponding HIN Gateway peer.

The fix was applied to the central services. Local virtual machine installations were not affected and did not require an update.

### What’s new and improved

- Separate relays can now be configured for senders and recipients.
- Emails to recipients outside the HIN network can be sent through the configured SMTP relay.
- The previous hourly email-processing limit has been removed.
- Sender and recipient matching has been improved for incoming and outgoing emails.
- Domain ownership is now checked before an S/MIME certificate is issued.
- Peer certificates can now be searched and sorted.
- TLS certificates can be generated directly from the dashboard.
- Search and pagination have been added to the peer overview.
- Searching through logs is now easier.
- A warning is shown when the private key has not been imported.
- Error messages and diagnostic information have been improved.
 
### Fixes
 
- Improved certificate selection when sending encrypted emails.
- Fixed the handling of encrypted messages signed with revoked or untrusted certificates.
- Fixed an issue with session refresh tokens.
- Fixed several errors in the setup and domain-management forms.
- Fixed country-code selection and field validation.
- Fixed an issue when regenerating an activation code.
- Fixed the processing of certain S/MIME signer information.
- Fixed missing connection information in tunnel delivery logs.
- Network settings are now correctly reset after the virtual machine’s IP address changes.

## v0.5.1

Our initial release.