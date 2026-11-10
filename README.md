# Azure VPN Client Deployment

Templates for deploying an Azure Point-to-Site VPN connection (Entra ID auth) to the Azure VPN Client. The profile includes DNS settings, and the connection is pushed silently with Intune, Datto RMM, GPO or a similar tool.

> [!NOTE]
> This README.md was summarised by Opus from my notes and scripts I gave it; take with a pinch of salt. The scripts + xml are methods I've used for years and never had an issue with.

## What's in the repo

| File | Purpose |
|---|---|
| `Customer Name - Client VPN.xml` | Azure VPN Client profile template. You import it into the Azure VPN Client, and the client then writes the connection to its `rasphone.pbk` file. |
| `importVPN.ps1` | Headless script that adds the connection to `rasphone.pbk` on end-user machines. It replaces an existing connection with the same name and leaves other connections alone. |

## Why use this XML template?

The profile you download from the Azure portal **does not include any DNS settings**. It has no DNS servers and no DNS suffixes. Without those, clients can't resolve internal names or Azure Private Endpoints (`*.file.core.windows.net`, `*.blob.core.windows.net`, `*.vaultcore.azure.net`, `*.database.windows.net`) over the tunnel.

This template already contains the `<dnsservers>` and `<dnssuffixes>` blocks. You copy the gateway-specific values from your Azure download into it.

## Step 1: Build the profile XML

1. In the Azure portal, download the VPN client profile:
   - **VPN Gateway:** *Virtual network gateway > Point-to-site configuration > Download VPN client*
   - **Virtual WAN:** *User VPN configurations > Download virtual WAN user VPN profile*
2. Extract the zip and open `AzureVPN\azurevpnconfig.xml`.
3. Copy the values from the Azure file into the template, replacing the placeholders:

| Placeholder | Where to find it |
|---|---|
| `{{TENANT_ID}}` | `<tenant>` / `<issuer>` in the Azure download (your Entra tenant ID) |
| `{{GATEWAY_FQDN}}` | `<fqdn>` in the Azure download |
| `{{SERVER_SECRET}}` | `<serversecret>` in the Azure download |
| `{{CUSTOMER_NAME}}` | Your choice. This becomes the connection name shown to users. |
| `{{DNS_SERVER_1}}` / `{{DNS_SERVER_2}}` | Your internal DNS servers or Azure DNS Private Resolver inbound endpoints |
| `{{INTERNAL_DOMAIN}}` | Your internal domain, e.g. `corp.contoso.com`. Add or remove `<dnssuffix>` lines as needed. |

4. Check `<audience>` and the cert `<hash>` against the Azure download as well. The template values are the Microsoft-registered Azure VPN Client app ID and the DigiCert Global Root G2 thumbprint, which most tenants use. If you use a custom app registration, or your download shows different values, use the download's values.
5. Rename the file to suit, e.g. `Contoso - Client VPN.xml`.

## Step 2: Generate the rasphone entry

The script doesn't use the XML directly. It writes the entry the Azure VPN Client creates when the XML is imported, so you need to capture that entry once on a test machine.

1. On a test machine, open the Azure VPN Client and use **+ > Import** to load your completed XML.
2. Connect and confirm that internal name resolution and access work.
3. Open the client's phonebook file:

   ```
   %LOCALAPPDATA%\Packages\Microsoft.AzureVpn_8wekyb3d8bbwe\LocalState\rasphone.pbk
   ```

   The package folder suffix may differ on your machines. If it does, override `-AzureVPNClientDirectory`.

4. Copy the whole section for your connection, from its `[Connection Name]` header line up to (but not including) the next `[...]` header.

## Step 3: Fill in the script

In `importVPN.ps1`:

- Set `$NewVPNHeader` to the header line exactly, including the brackets, e.g. `"[Contoso - Client VPN]"`.
- Paste the copied section into the `$RASPhoneEntry` here-string, replacing the `REPLACE ME` text. Keep the header as the first line and leave a trailing empty line.
- Change `$ScriptLogLocation` from `C:\ExampleFolder\...` to your preferred log folder.

## Step 4: Deploy

The script is **headless**. Run it with your management tool; don't hand it to users.

- **Intune:** *Devices > Scripts and remediations > Platform scripts*. Set **Run this script using the logged on credentials** to **Yes**.
- **RMM:** run the component as the **logged-in user**.
- **GPO:** assign it as a **user logon script**.

> The script writes to `%LOCALAPPDATA%`, so it **must run in the user's context**. If it runs as SYSTEM, the connection goes into the SYSTEM profile and users won't see it.

The script doesn't install the Azure VPN Client. Deploy the client separately (Microsoft Store app via Intune, or `winget install 9NP355QT2SQB`). If the client isn't installed yet, the script creates the `LocalState` folder and phonebook so the connection is there when the client is installed.

Each run backs up the existing phonebook to `rasphone_backupNN.pbk` in the same folder before changing it.

## Security

The completed XML and the completed `importVPN.ps1` both contain your gateway's **server secret**. The `ThirdPartyProfileInfo` lines in the rasphone entry are the profile XML encoded as hex.

- Don't commit completed copies to a public repo. Keep this repo as templates only.
- Distribute the completed script only through your management tool, not by email or file share.



