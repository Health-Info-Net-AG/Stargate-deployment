# Renew and revoke domain certificates

Each domain in HIN Gateway has a domain certificate. HIN Gateway uses it to sign and encrypt messages for the domain. In the dashboard you can let HIN Gateway renew the certificate automatically, revoke a certificate and issue a new one.

How it works:

- A certificate has one of three statuses: **Good**, **Revoked** or **Expired**
- With **Auto renew** switched on, HIN Gateway renews the certificate automatically before it expires
- A revoked certificate can no longer be used. Revoking cannot be undone
- From an expired or revoked certificate you can issue a new certificate. HIN Gateway generates new public and private keys for it

## Before you start

- You need access to the HIN Gateway dashboard
- The domain must already be added in HIN Gateway and onboarded

## View the domain certificates

1. Log in to the HIN Gateway dashboard.
2. Go to **Domains** and select the domain.
3. Go to the **Domain certificates** section.

    ![Domain certificates section with a certificate in status Good](./assets/domain-certs-1.png)

    For each certificate the section shows the **Serial Number**, the validity period (**Valid from** and **Valid until**) and the **Status**. A certificate that expires soon is marked **Expiring soon**, and its **Valid until** date is shown in red.

## Filter certificates by status

Use the **Status** filter in the top right corner of the section to choose which certificates are shown:

- **Good:** valid certificates currently in use
- **Revoked:** certificates that were revoked
- **Expired:** certificates whose validity period has ended

![Domain certificates filtered by status Revoked](./assets/domain-certs-4.png)

## Turn auto renew on or off

The **Auto renew** switch controls whether HIN Gateway renews the certificate automatically:

- **On:** HIN Gateway renews the certificate automatically when it is about to expire. This is recommended
- **Off:** the certificate is not renewed. When it expires, you have to issue a new certificate manually

Click the switch to change the setting.

!!! warning
    If auto renew is off and the certificate expires, HIN Gateway can no longer sign and encrypt messages with it until you issue a new certificate.

## Revoke a certificate

Revoke a certificate if you no longer want it to be used, for example if you suspect that the key is compromised.

1. In the **Domain certificates** section, find the certificate you want to revoke
2. Click the red **Revoke** icon (crossed circle). A confirmation window opens

    ![Revoke certificate confirmation](./assets/domain-certs-2.png)

3. Click **Revoke** to confirm, or **Cancel** to keep the certificate.

!!! warning
    Revoking a certificate cannot be undone. The certificate now has the status **Revoked** and appears under the **Revoked** filter.

## Issue a new certificate

You can issue a new certificate from an expired or a revoked certificate.

1. In the **Status** filter, select **Expired** or **Revoked**.
2. Find the certificate and click the **Renew** icon (clock with arrow). A confirmation window opens.

    ![Renew certificate confirmation](./assets/domain-certs-3.png)

3. Click **Renew** to confirm, or **Cancel** to stop.

HIN Gateway generates new public and private keys and issues the new certificate. If the old certificate was still valid, it is revoked.

!!! note
    It may take a few hours for the new certificate to reach all other participants. During this time you can still decrypt messages with your current private key.

## Verify the new certificate

Select **Good** in the **Status** filter. The new certificate is listed with the status **Good** and a new **Serial Number** and validity period.
