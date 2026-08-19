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