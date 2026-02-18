<#
.SYNOPSIS
    Script de déploiement automatique pour le TD Active Directory.
    A exécuter sur le Contrôleur de Domaine une fois disponible.

.DESCRIPTION
    Ce script lit le fichier users.csv et effectue les actions suivantes :
    1. Création de l'OU correspondant au Service (si elle n'existe pas).
    2. Création d'un Groupe Global pour ce service (ex: GG_Comptable).
    3. Création du compte utilisateur.
    4. Ajout de l'utilisateur au groupe.
#>

# --- CONFIGURATION ---
# Le script cherche le csv dans le même dossier que lui-même
$CsvFile = "$PSScriptRoot\users.csv"
$DomainName = "dev.serval.int"  
#$DomainDN = "DC=corp,DC=lan" # A ADAPTER (ex: corp.lan -> DC=corp,DC=lan)
$DefaultPassword = ConvertTo-SecureString "Password1!" -AsPlainText -Force

# --- IMPORT ---
try {
    # On force le délimiteur à la virgule car ton fichier users.csv l'utilise
    $UsersList = Import-Csv -Path $CsvFile -Delimiter ","
}
catch {
    Write-Error "Erreur: Impossible de trouver ou lire le fichier $CsvFile"
    exit
}

# --- TRAITEMENT ---
foreach ($User in $UsersList) {
    $Service = $User.Service
    $Login = $User.Login
    $FullName = "$($User.Prenom) $($User.Nom)"
    
    # 1. Gestion de l'OU
    # On crée une OU par service à la racine du domaine
    $OUPath = "OU=$Service,$DomainDN"
    
    try {
        # On essaie de créer l'OU. Si elle existe, ça génère une erreur qu'on ignore (catch)
        New-ADOrganizationalUnit -Name $Service -Path $DomainDN -ErrorAction Stop
        Write-Host "[OK] OU créée : $Service" -ForegroundColor Green
    }
    catch {
        # L'OU existe déjà, on continue
    }

    # 2. Gestion du Groupe Global (AGDLP)
    $GroupName = "GG_$Service"
    try {
        New-ADGroup -Name $GroupName -GroupScope Global -Path $OUPath -ErrorAction Stop
        Write-Host "[OK] Groupe créé : $GroupName" -ForegroundColor Green
    }
    catch {
        # Le groupe existe déjà
    }

    # 3. Création Utilisateur
    try {
        New-ADUser -Name $FullName `
                   -SamAccountName $Login `
                   -UserPrincipalName "$Login@$DomainName" `
                   -Path $OUPath `
                   -AccountPassword $DefaultPassword `
                   -Enabled $true `
                   -ChangePasswordAtLogon $true `
                   -ErrorAction Stop
        
        # 4. Ajout au groupe
        Add-ADGroupMember -Identity $GroupName -Members $Login
        Write-Host "[OK] Utilisateur $Login créé et ajouté au groupe $GroupName" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "[INFO] L'utilisateur $Login existe probablement déjà."
    }
}