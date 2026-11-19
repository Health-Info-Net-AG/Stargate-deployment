# Delete a domain

You can delete a domain from HIN Gateway when it should no longer send or receive email through the gateway, for example after the domain has been retired or moved to another system.

## Before you delete

- Make sure no system still sends email for the domain through HIN Gateway. After the domain is deleted, HIN Gateway no longer processes messages for it
- Decide whether the domain certificate should be revoked. Revoking cannot be undone

## Delete the domain

1. Log in to the HIN Gateway dashboard.
2. Go to **Domains** and select the domain you want to delete. The **Domain details** page opens.
3. Click the red **Delete** icon (trash bin) next to the domain status.

    ![Domain details page with the delete icon](./assets/delete-domain-1.png)

    A confirmation window opens.

    ![Delete domain confirmation](./assets/delete-domain-2.png)

4. Choose whether to revoke the domain certificate:

    - **Revoke domain's certificate** selected: the certificate of the domain is also revoked when the domain is deleted
    - **Revoke domain's certificate** not selected: the domain is deleted, but its certificate is not revoked

5. Click **Yes** to delete the domain, or **No** to cancel.

The domain is removed from the **Domains** list.

!!! warning
    If you select **Revoke domain's certificate**, the certificate is revoked and cannot be used again. Revoking cannot be undone.