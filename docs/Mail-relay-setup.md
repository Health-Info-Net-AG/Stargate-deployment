# Stargate mail relay setup

## Create a stargate relay for a mail domain hosted in Microsoft Office 365

For the relay, we need a VM or a server with a real static IP address.

In this example we will use a VM with IP address `128.140.117.200` and hostname `mail.vrgnservices.eu` to relay mail for domain `vrgnservices.eu`.

## Set up DNS records

See the [DNS Setup Guide](./DNS-setup.md) for complete instructions on all required records (A, MX, SPF, PTR, DMARC, DKIM).

Quick example for domain `vrgnservices.eu` with Stargate IP `128.140.117.200`:

* **A record**: `mail.vrgnservices.eu` → `128.140.117.200`
* **MX record**: `MX @ 15 mail.vrgnservices.eu.` (higher priority than the existing Exchange MX at 20)
* **SPF record**: `v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all`

Verify:

```shell
# host mail.vrgnservices.eu
mail.vrgnservices.eu has address 128.140.117.200
```

```shell
# host -t mx vrgnservices.eu
vrgnservices.eu mail is handled by 20 vrgnservices-eu.mail.protection.outlook.com.
vrgnservices.eu mail is handled by 15 mail.vrgnservices.eu.
```

```shell
# host -t txt vrgnservices.eu|grep v=spf1
vrgnservices.eu descriptive text "v=spf1 ip4:128.140.117.200 include:spf.protection.outlook.com -all"
```

## Install the stargate docker compose containers

[Stargate Deployment](./Docker-deploy.md)

### Requirements

* **2 CPU cores** (minimum)
* **4 GB RAM** (minimum)
* **20 GB storage** (minimum)
* **Root access**: Must be run as root or with `sudo`
* **Supported distributions**:
    * RHEL 8, 9 and 10 compatible distributions such as Alma Linux, Rocky Linux, Centos Stream
    * Ubuntu 22 and 24
    * Debian 11, 12 and 13
* **Real IPv4 address**
* **Valid DNS records**: Your domain must have:
    * MX records pointing to your mail servers
    * SPF record defining allowed sending networks

The script installs all components and starts them. Mail domains and the Stalwart hostname are then configured at runtime via the dashboard's `/mail` page (the mtaconf daemon extracts the necessary mail relay settings from DNS based on those domains).

## Set up Exchange

We need to configure connectors and a transport rule in Exchange to relay all outgoing mail to the Stargate relay and allow incoming mail from it.

Navigate to [https://admin.exchange.microsoft.com/#/connectors](https://admin.exchange.microsoft.com/#/connectors)

### Outgoing connector

Create outgoing mail connector, click"Add":

Select "Connection from": "Office 365" "Connection to": "your organization&#39;s email server, click "Next".

![screenshot](./assets/new_connector_outgoing1.png)

Name it something like "From Office 365 to Stargate relay server" and check "Retain Internal Exchange email headers", click "Next".

![screenshot](./assets/new_connector_outgoing2.png)

Select "Only when I have a transport rule set up that redirects messages to this connector", click Next,.

![screenshot](./assets/new_connector_outgoing3.png)

Enter the IP address of the Stargate relay server, click "+", click "Next".

![screenshot](./assets/new_connector_outgoing4.png)

Select "Any digital certificate, including self-signed certificates", click "Next".

![screenshot](./assets/new_connector_outgoing5.png)

Enter a valid email address for your domain, click "+", click "Validate", click "Next".

![screenshot](./assets/new_connector_outgoing6.png)

Click "Create connector".

![screenshot](./assets/new_connector_outgoing7.png)

Click "Add another connector".

![screenshot](./assets/new_connector_outgoing8.png)

### Incoming connector

Create incoming mail connector, choose "Connection from": "Your organization's email server", click "Next".

![screenshot](./assets/new_connector_incoming1.png)

Name it something like "Receive mail from Stargate relay server" and check "Retain internal Exchange email headers", click "Next.

![screenshot](./assets/new_connector_incoming2.png)

Select "By verifying that the IP address of the sending server matches one of the following IP addresses, type the IP address of the Stargate server, click "+", click "Next".

![screenshot](./assets/new_connector_incoming3.png)

Click "Create connector".

![screenshot](./assets/new_connector_incoming4.png)

Click "Done".

![screenshot](./assets/new_connector_incoming5.png)

This is how it looks when done:

![screenshot](./assets/new_connector_incoming6.png)

### Transport Rule

Create the transport rule, navigate to [https://admin.exchange.microsoft.com/#/transportrules](https://admin.exchange.microsoft.com/#/transportrules)

Click "+Add a rule" --> "Create a new rule".

![screenshot](./assets/new_transport_rule1.png)

Name it something like "Relay all mail to Stargate except mail coming from it", choose "Apply rule if" "The recipient:" "is external/internal" "Outside the organization", click "Save".  

![screenshot](./assets/new_transport_rule2.png)

Choose "Do the following" "Redirect message to the following connector" "From Office 365 to Stargate relay server", click "Save".

![screenshot](./assets/new_transport_rule3.png)

Choose "Except if The sender IP address is in any of these ranges" enter the IP address of the Stargate server, click "Add", check the IP address and click "Save".

This is needed to prevent mail loops, as this rule also applies to other domains hosted in Office 365.  

![screenshot](./assets/new_transport_rule4.png)

Now it should look like this, click "Next":

![screenshot](./assets/new_transport_rule5.png)

Click "Next".

![screenshot](./assets/new_transport_rule6.png)

Click "Finish".

![screenshot](./assets/new_transport_rule7.png)

Click "Done".

![screenshot](./assets/new_transport_rule8.png)

![screenshot](./assets/new_transport_rule9.png)

Click on the rule and set the "Enable or disable rule to "Enabled"  

![screenshot](./assets/new_transport_rule10.png)
