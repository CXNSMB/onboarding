# Customer Roles Deployment

Dit script deployment systeem zorgt voor het aanmaken van Entra ID groepen en het toewijzen van de juiste rollen voor tenant en subscription management.

## Quick Start - Azure Cloud Shell (Browser)

De snelste manier om te starten is via Azure Cloud Shell in je browser:

1. Open [Azure Cloud Shell](https://shell.azure.com) in je browser
2. Selecteer **PowerShell** als shell type
3. Kopieer en plak het volgende commando:

```powershell
# Download en voer het script uit (zonder parameters - geeft instructies)
iwr 'https://raw.githubusercontent.com/CXNSMB/onboarding/main/entra-groups-setup/deploy-entra-groups.ps1' | iex
```

4. Je krijgt een foutmelding omdat geen TenantCode parameter is meegegeven
5. Druk op pijltje omhoog ↑ om het commando terug te halen
6. Voeg `-TenantCode "jouw-tenant-code"` toe aan het einde:

```powershell
# Met TenantCode parameter
iwr 'https://raw.githubusercontent.com/CXNSMB/onboarding/main/entra-groups-setup/deploy-entra-groups.ps1' | iex -TenantCode "jouw-tenant-code"
```

Vervang `"jouw-tenant-code"` met je daadwerkelijke tenant code (bijv. "7qx45m").

### Alternatief: Download eerst, voer later uit

Als je het script wilt bekijken voordat je het uitvoert:

```powershell
# Download het script
iwr 'https://raw.githubusercontent.com/CXNSMB/onboarding/main/entra-groups-setup/deploy-entra-groups.ps1' -OutFile 'deploy-entra-groups.ps1'

# Bekijk het script
cat deploy-entra-groups.ps1

# Voer het uit
./deploy-entra-groups.ps1 -TenantCode "jouw-tenant-code"
```

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
- **Azure CLI** geïnstalleerd en ingelogd (in Cloud Shell al beschikbaar)
- **Geen PowerShell modules vereist**

## Gebruik (Lokaal of in Cloud Shell Storage)

### 1. Zorg dat je bent ingelogd in de juiste subscription
```powershell
# Controleer huidige context
az account show

# Wissel naar gewenste subscription indien nodig
az account set --subscription "your-subscription-id"
```

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
   - **Oplossing**: Run `az login` of gebruik Azure Cloud Shell (al ingelogd)

3. **"Insufficient privileges"**
   - **Oplossing**: Zorg voor Global Admin + Subscription Owner rechten

4. **"PrincipalNotFound" errors bij RBAC assignments**
   - **Oplossing**: Dit is normaal bij eerste run (replication delay)
   - Run het script nogmaals, het wijst alleen missende rollen toe

5. **"Group already exists" warnings**
   - **Dit is normaal**: Script is idempotent, herkent bestaande groepen
   - Geen actie nodig

6. **Config.json niet gevonden bij tweede subscription**
   - **Oplossing**: Zorg dat `config.json` in dezelfde directory staat
   - Of download eerst vanuit Cloud Shell storage/GitHub

### Debug informatie
Het script toont uitgebreide logging:
- 🔵 Cyan: Informatie over wat er uitgevoerd wordt
- 🟢 Green: Succesvolle acties
- 🟡 Yellow: Waarschuwingen (meestal OK)
- 🔴 Red: Errors (vereisen actie)

### Cloud Shell specifiek
- Scripts in Cloud Shell storage blijven bewaard tussen sessies
- Config.json wordt opgeslagen in dezelfde directory als het script
- Bij gebruik van één-regel commando wordt config.json NIET bewaard
- Voor multi-subscription: download script eerst, voer lokaal uit

## Best Practices

1. **Test eerst met -WhatIf** om te zien wat er gebeurt
2. **Run script twee keer** bij nieuwe tenant (eerste keer: groepen, tweede keer: fix replication delays)
3. **Bewaar config.json** voor multi-subscription setups
4. **Gebruik Cloud Shell** voor snelle setup zonder lokale installatie
5. **Download script lokaal** voor productie gebruik met meerdere subscriptions