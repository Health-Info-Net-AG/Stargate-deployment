# Managing Routed Domains in HIN Gateway

HIN Gateway can also manage traffic for domains that are not HIN Secure domains. a common setup for customers who run their own on-premises email server infrastructure.
This capability is built into HIN Gateway and gives customers the flexibility to shape their communication environment precisely to their needs.

In HIN Gateway, these domains are called **Routed** domains.
A Routed domain is a domain whose traffic passes through HIN Gateway without being processed for secure messaging - it is mainly forwarded on to the next relay host.


### Add a Routed domain

Go to the **Domains** page, click **Add domain**, enter the domain name and then click **Save**.

<br> ![Screenshot](assets/routed-domains/add-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }

### Configure the Routed domain

Activate the domain and configure it the same way as any other HIN Secure domain. For detailed configuration steps, see the [mail transport configuration guide](https://health-info-net-ag.github.io/Stargate-deployment/Installation-guide/#step-14-configure-mail-transport).


<br> ![Screenshot](assets/routed-domains/activate-routed-domain.png){ style="position:relative;left:50%;transform:translate(-50%,0%);" }