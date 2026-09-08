# Migrating S/MIME domain keys from a 5.x install to 6.x

Exports a domain's S/MIME certificate(s) and private key(s) from an old 5.x
stargate host and prepares a password-protected PKCS#12 (`.p12`) file that the
6.x dashboard's domain form can import.

| Script                 | Runs on                          | Purpose |
|------------------------|----------------------------------|---------|
| `export-smime-keys.sh` | the **old 5.x VM**               | Fetches cert + private key per domain from the running smimekeys-client API and writes `.cert.pem`, `.key.pem` and `.p12` files. |
| `pem-to-p12.sh`        | **your workstation** (needs only `openssl`) | Builds the `.p12` from pasted/copied PEM content. Only needed when you cannot `scp` files off the VM. |

## Step 1 — create the export script on the old 5.x VM

Open the script on your workstation, copy its full content, then on the VM
create the file and paste it in:

```bash
ssh user@old-vm
nano /tmp/export-smime-keys.sh     # paste the content of export-smime-keys.sh, save & exit
chmod +x /tmp/export-smime-keys.sh
```

(Any editor works -- `vi /tmp/export-smime-keys.sh` and paste with `i`, save
with `:wq`.)

## Step 2 — run the export on the old VM

SSH in and run it once per domain (the `stargate-smimekeys-client` container
must be running; `jq` must be installed):

```bash
ssh user@old-vm
cd /tmp
./export-smime-keys.sh example.com
```

You are prompted for a password (twice) that will protect the `.p12` --
remember it, the dashboard asks for it at import. Output lands in
`/tmp/smime-export/example.com/`:

```
example.com.cert.pem   example.com.key.pem   example.com.p12
```

A domain with more than one key pair additionally gets `example.com_2.*`, etc.

## Step 3a — copy the files to your workstation (scp route)

From your workstation:

```bash
# just the .p12 (all the dashboard needs):
scp user@old-vm:/tmp/smime-export/example.com/example.com.p12 .

# or the whole export directory (pem + p12):
scp -r user@old-vm:/tmp/smime-export/example.com .
```

The files are mode 0600, owned by whoever ran the export -- if scp says
"permission denied", run the export as the same user you ssh in with.

## Step 3b — no scp available? copy-paste route

On the old VM, print the PEM files and copy the terminal output:

```bash
cat /tmp/smime-export/example.com/example.com.key.pem \
    /tmp/smime-export/example.com/example.com.cert.pem
```

On your workstation, rebuild the `.p12` from the copied text:

```bash
./pem-to-p12.sh          # paste the PEM content, press Ctrl-D, set a password
#   ✓ example.com.p12
```

Stray text around the PEM blocks (shell prompts, the `cat` command line) is
ignored, and the key/cert paste order does not matter.

## Step 4 — import into the 6.x dashboard

Open the 6.x dashboard, go to the domain's form (edit or onboarding), upload
the `.p12` in the certificate section and enter the password from step 2 (or
3b). The dashboard extracts the certificate and private key from the file in
the browser and stores them for the domain.

## Step 5 — clean up

The exported files contain the private key in clear text. Once the import is
verified, delete them on both ends:

```bash
ssh user@old-vm rm -rf /tmp/smime-export /tmp/export-smime-keys.sh
rm -f example.com.p12 example.com.cert.pem example.com.key.pem
```
