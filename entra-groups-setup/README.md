# Customer Roles Deployment

Dit script deployment systeem zorgt voor het aanmaken van Entra ID groepen en het toewijzen van de juiste rollen voor tenant en subscription management.

## Waarom niet Azure Cloud Shell?

**Cloud Shell heeft inconsistente Graph API permissions** die dit script onbetrouwbaar maken:

- ✅ **Lokaal met `az login --use-device-code`**: Je krijgt **Directory.AccessAsUser.All** delegated permission
  - Deze permission geeft volledige toegang tot alle Graph API operaties die jij als gebruiker mag uitvoeren
  - Werkt altijd consistent voor Global Administrators
  
- ❌ **Cloud Shell**: Gebruikt een **managed identity** met beperkte permissions
  - Soms krijg je alleen **Directory.ReadWrite.All** (zonder AccessAsUser.All)
  - Deze permission is onvoldoende voor:
    - Aanmaken van role-assignable groups (vereist RoleManagement.ReadWrite.Directory)
    - Aanmaken van Administrative Units
    - Toewijzen van AU-scoped roles
  - Permissions zijn **niet consistent** tussen tenants
  - Je kunt de permissions van de Cloud Shell managed identity niet aanpassen

**Voorbeeld uit testing:**
```
Tenant 7qx45m: Had Directory.AccessAsUser.All → Werkte perfect
Tenant xyz001: Alleen Directory.ReadWrite.All → Faalden AU en role-assignable groups
```

**Daarom: Script is ontworpen voor lokale PowerShell uitvoering met device code authentication.**

## Quick Start - Lokale PowerShell (Aanbevolen)

## Quick Start - Lokale PowerShell (Aanbevolen)

Het script detecteert automatisch of je bent ingelogd en logt je zo nodig in met device code authentication:

1. Download het script naar een lokale folder:

```powershell
# Download het script
iwr 'https://raw.githubusercontent.com/CXNSMB/onboarding/main/entra-groups-setup/deploy-entra-groups.ps1' -OutFile 'deploy-entra-groups.ps1'
```

2. Voer het script uit (automatische login indien nodig):

```powershell
# Eerste keer met TenantCode
./deploy-entra-groups.ps1 -TenantCode "jouw-tenant-code"

# Toon wachtwoorden van nieuw aangemaakte users
./deploy-entra-groups.ps1 -TenantCode "jouw-tenant-code" -ShowPassword
```

3. Het script:
   - ✅ Controleert of je bent ingelogd
   - ✅ Controleert of Graph API token nog geldig is
   - ✅ Logt automatisch in met device code indien nodig
   - ✅ Logt automatisch uit na afloop (alleen als script zelf heeft ingelogd)

## Alternatief - Cloud Shell (Niet Aanbevolen)

⚠️ **Werkt mogelijk niet** vanwege inconsistente Graph API permissions (zie boven).

Als je het toch wilt proberen:

```powershell
# Download en voer het script uit
iwr 'https://raw.githubusercontent.com/CXNSMB/onboarding/main/entra-groups-setup/deploy-entra-groups.ps1' -OutFile 'deploy-entra-groups.ps1'

# Voer uit
./deploy-entra-groups.ps1 -TenantCode "jouw-tenant-code"
```

Als je errors krijgt over "Insufficient privileges" of "Authorization_RequestDenied", gebruik dan de lokale PowerShell methode.

## Beschikbare Scripts

### `deploy-entra-groups.ps1` - Unified Complete Setup Script
**Standalone script** dat alle Entra ID setup doet met Microsoft Graph REST API via Azure CLI. Geen PowerShell modules vereist.

**Features:**
- ✅ Hard-coded groep definities (standalone, geen externe bestanden nodig)
- ✅ Gebruikt alleen Azure CLI (geen PowerShell modules)
- ✅ Ondersteunt meerdere subscriptions in één config.json
- ✅ Maakt Restricted Administrative Unit aan
- ✅ Maakt MSP admin user aan met AU-scoped roles (User Administrator, Groups Administrator)
- ✅ Maakt customer admin user aan als AU member (geen roles)
- ✅ Automatische login/logout met device code flow
- ✅ Alle groepen in AU met HiddenMembership
- ✅ Tenant-level Entra directory rollen
- ✅ Subscription-level RBAC rollen
- ✅ Azure Reservations RBAC rollen (tenant-level)

## Vereisten

- **Global Administrator** rechten in Entra ID
- **Subscription Owner** rechten op de doelsubscriptie
- **PowerShell 7+** (lokaal geïnstalleerd)
- **Azure CLI** geïnstalleerd en beschikbaar in PATH
- **Device code authentication** (script logt automatisch in indien nodig)
- **Geen PowerShell modules vereist** (alleen Azure CLI)

## Gebruik (Lokaal PowerShell)

### 1. Zorg dat Azure CLI is geïnstalleerd
```powershell
# Check of Azure CLI beschikbaar is
az --version

# Indien niet geïnstalleerd: https://learn.microsoft.com/cli/azure/install-azure-cli
```

Het script controleert automatisch je login status en logt in indien nodig.

### 2. Eerste keer uitvoeren (nieuwe tenant)
```powershell
# Voer uit met TenantCode parameter (wachtwoorden worden NIET getoond)
./deploy-entra-groups.ps1 -TenantCode "7qx45m"

# Of met wachtwoorden in output (voor initiële setup)
./deploy-entra-groups.ps1 -TenantCode "7qx45m" -ShowPassword
```

Dit maakt:
- Administrative Unit: `7qx45m-tenant-admin`
- MSP admin user: `7qx45m-cxnmsp-admin@<domain>` (met AU-scoped rollen)
- Customer admin user: `7qx45m-cust-admin@<domain>` (als AU member)
- Tenant groepen: `sec-tenant-*`
- Subscription groepen: `sec-az-<prefix>-*`
- `<tenantcode>-config.json` bestand

### 3. Extra subscription toevoegen
```powershell
# Script detecteert automatisch dat je al bent ingelogd
# Wissel naar andere subscription
az account set --subscription "andere-subscription-id"

# Voer script uit (leest TenantCode uit config.json)
./deploy-entra-groups.ps1
```

Het script herkent automatisch dat het om dezelfde tenant gaat en voegt de subscription toe aan de bestaande config.

### 4. WhatIf mode (test zonder wijzigingen)
```powershell
./deploy-entra-groups.ps1 -TenantCode "7qx45m" -WhatIf
```

## Wat doet het script?

### Administrative Unit (AU)
- Maakt een **Restricted Administrative Unit** aan: `<tenantcode>-tenant-admin`
- **isMemberManagementRestricted**: `true` (restricted management)
- **Visibility**: `HiddenMembership` (alleen AU admins zien members)
- **MSP admin user** (`<tenantcode>-cxnmsp-admin@<onmicrosoft.domain>`):
  - Wordt aangemaakt met complex wachtwoord (16 tekens)
  - Toegevoegd aan AU met AU-scoped rollen:
    - User Administrator
    - Groups Administrator
- **Customer admin user** (`<tenantcode>-cust-admin@<onmicrosoft.domain>`):
  - Wordt aangemaakt met complex wachtwoord (16 tekens)
  - Toegevoegd aan AU als member (geen rollen)

### Tenant Level Groepen
Het script maakt de volgende tenant-level groepen aan en wijst rollen toe:

**Groepen met Entra Directory Rollen (tenant-wide):**
- `sec-tenant-dailyadmin` - Daily operations
  - User Administrator
  - Groups Administrator
- `sec-tenant-privadmin` - Privileged roles
  - User Administrator
  - Groups Administrator
  - Privileged Role Administrator
  - Security Administrator
  - Application Administrator
  - Global Reader

**Groepen met Azure Reservations RBAC Rollen (tenant-level, scope: `/providers/Microsoft.Capacity`):**
- `sec-tenant-reservations-read` → Reservations Reader
- `sec-tenant-reservations-admin` → Reservations Administrator
- `sec-tenant-reservations-purchase` → Reservation Purchaser

**Informational groep:**
- `sec-tenant-break-glass` - Break glass accounts (geen rollen)

### Subscription Level Groepen
Voor elke subscription worden groepen aangemaakt met het patroon `sec-az-<subscription-prefix>-<role>`:

- `sec-az-xxx-reader` → Reader
- `sec-az-xxx-dailyadmin` → Reader, Backup Reader, Desktop Virtualization VM Contributor, Desktop Virtualization User Session Operator
- `sec-az-xxx-contributor` → Contributor
- `sec-az-xxx-costreader` → Cost Management Reader
- `sec-az-xxx-sec-uaa` → User Access Administrator
- `sec-az-xxx-owner` → Owner

Waarbij `xxx` de eerste 8 karakters van de subscription ID is (tot eerste streepje).

### Config.json Structuur
Het script bewaart alle informatie in `config.json`:
```json
{
  "tenantconfig": {
    "tenantCode": "7qx45m",
    "tenantId": "...",
    "restrictedAdminUnitId": "...",
    "groups": {
      "sec-tenant-dailyadmin": "guid",
      "sec-tenant-privadmin": "guid",
      ...
    }
  },
  "subscriptions": {
    "subscription-id-1": {
      "prefix": "sec-az-759e1a27",
      "groups": {
        "reader": "guid",
        "dailyadmin": "guid",
        ...
      }
    },
    "subscription-id-2": { ... }
  }
}
```

## Foutafhandeling

Het script:
- ✅ Controleert of groepen al bestaan voordat het ze aanmaakt (idempotent)
- ✅ Controleert of rol assignments al bestaan (idempotent)
- ✅ Verifieert dat groepen echt bestaan via Graph API (niet alleen via config)
- ✅ Gebruikt `--assignee-principal-type Group` voor RBAC assignments
- ✅ Wacht 15 seconden tussen groep aanmaken en RBAC assignments (replicatie)
- ✅ Logt alle acties met kleurgecodeerde output
- ✅ Multi-subscription support: behoudt bestaande subscriptions in config

### Typische workflow bij fouten:
1. **Eerste run**: Mogelijk enkele replication delay errors bij RBAC
2. **Tweede run**: Script herkent bestaande groepen en wijst alleen missende rollen toe
3. **Resultaat**: Alle groepen en rollen correct geconfigureerd

## Parameters

- `-TenantCode` (optioneel na eerste run): Tenant code voor groepnamen (bijv. "7qx45m")
- `-WhatIf`: Test mode, geen wijzigingen
- `-SetupEntraOnly`: Alleen AU en Entra roles, geen nieuwe groepen
- `-ShowPassword`: Toon wachtwoorden van nieuw aangemaakte users in output
- `-ConfigFile`: Pad naar config.json (default: `$PSScriptRoot/<tenantcode>-config.json`)

## Verificatie

Na het uitvoeren van het script kun je alles verifiëren:

```powershell
# Bekijk alle aangemaakte groepen
az ad group list --filter "startswith(displayName, 'sec-')" --output table

# Bekijk AU properties
az rest --method GET --url "https://graph.microsoft.com/v1.0/directory/administrativeUnits/<au-id>"

# Bekijk RBAC assignments op subscription
az role assignment list --subscription "<subscription-id>" --output table

# Bekijk tenant-level RBAC (reservations)
az role assignment list --scope "/providers/Microsoft.Capacity" --output table

# Bekijk config.json
cat config.json | jq
```

## Bestanden

- `deploy-entra-groups.ps1` - Unified deployment script (standalone)
- `config.json` - Configuratie met alle groepen en subscriptions (wordt automatisch aangemaakt)
- `README.md` - Deze documentatie

## Troubleshooting

### Veel voorkomende problemen:

1. **"Config file does not exist and no TenantCode parameter provided"**
   - **Oplossing**: Dit is verwacht bij eerste run vanuit Cloud Shell
   - Druk op pijltje omhoog ↑ en voeg `-TenantCode "jouw-code"` toe

2. **"Not logged in to Azure CLI"**
   - **Oplossing**: Script logt automatisch in met device code
   - Of handmatig: `az login --use-device-code`

3. **"Insufficient privileges" of "Authorization_RequestDenied"**
   - **Mogelijke oorzaak**: Cloud Shell met beperkte permissions
   - **Oplossing**: Gebruik lokale PowerShell in plaats van Cloud Shell
   - Zorg voor Global Admin + Subscription Owner rechten

4. **"PrincipalNotFound" errors bij RBAC assignments**
   - **Oplossing**: Dit is normaal bij eerste run (replication delay)
   - Run het script nogmaals, het wijst alleen missende rollen toe

5. **"Group already exists" warnings**
   - **Dit is normaal**: Script is idempotent, herkent bestaande groepen
   - Geen actie nodig

6. **Config.json niet gevonden bij tweede subscription**
   - **Oplossing**: Zorg dat `<tenantcode>-config.json` in dezelfde directory staat
   - Script zoekt naar config met tenantcode in bestandsnaam

7. **"Graph API token expired or invalid"**
   - **Dit is normaal**: Token verloopt na 1 uur
   - **Oplossing**: Script detecteert dit automatisch en logt opnieuw in
   - Geen handmatige actie nodig

### Cloud Shell specifieke problemen

8. **"Authorization_RequestDenied" bij Administrative Unit of role-assignable groups**
   - **Oorzaak**: Cloud Shell managed identity heeft geen Directory.AccessAsUser.All permission
   - **Oplossing**: Gebruik lokale PowerShell met device code authentication
   - Cloud Shell permissions zijn niet consistent tussen tenants

### Debug informatie
Het script toont uitgebreide logging:
- 🔵 Cyan: Informatie over wat er uitgevoerd wordt
- 🟢 Green: Succesvolle acties
- 🟡 Yellow: Waarschuwingen (meestal OK)
- 🔴 Red: Errors (vereisen actie)

### Authentication troubleshooting
- Script test automatisch of Graph API token geldig is
- Bij verlopen token: automatische re-login met device code
- Bij eerste run zonder login: automatische device code login
- Automatische logout na afloop (alleen als script zelf heeft ingelogd)
- Device code werkt ook in devcontainer/Codespaces (geen browser vereist)

## Best Practices

1. **Gebruik lokale PowerShell** (niet Cloud Shell) voor betrouwbare Graph API permissions
2. **Test eerst met -WhatIf** om te zien wat er gebeurt
3. **Run script twee keer** bij nieuwe tenant (eerste keer: groepen, tweede keer: fix replication delays)
4. **Bewaar config.json** voor multi-subscription setups
5. **Gebruik -ShowPassword** alleen bij initiële setup om wachtwoorden te zien
6. **Device code authentication** werkt ook in devcontainer/Codespaces
7. **Script logt automatisch in/uit** - geen handmatige `az login` nodig