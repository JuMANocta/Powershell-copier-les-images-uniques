# Cette section contient des fonctions de base pour interagir avec les disques

# Fonction pour récupérer les disques amovibles
function Get-ExternalDrives {
    return Get-Volume
}

# Fonction pour afficher les informations des disques amovibles
function Show-ExternalDrives {
    param($drives)
    Write-Host "Disques amovibles disponibles:" -ForegroundColor Green
    foreach ($drive in $drives) {
        Write-Host ("Lettre: " + $drive.DriveLetter + "`t" + "Taille: " + $drive.SizeRemaining + "/" + $drive.Size + "`t" + "Type de système de fichiers: " + $drive.FileSystem) -ForegroundColor Cyan
    }
}

# Fonction pour valider la lettre de lecteur entrée par l'utilisateur
function Validate-DriveLetter {
    param($driveLetter, $drives)
    return $drives.DriveLetter -contains $driveLetter
}

# Fonction pour permettre à l'utilisateur de sélectionner un disque
function Select-Drive {
    $externalDrives = Get-ExternalDrives
    if (-not $externalDrives) {
        Write-Host "Aucun disque amovible trouvé." -ForegroundColor Red
        exit
    }
    Show-ExternalDrives -drives $externalDrives

    $selected = Read-Host "Entrez la lettre du disque que vous souhaitez utiliser"
    if (Validate-DriveLetter -driveLetter $selected -drives $externalDrives) {
        return $selected
    }
    else {
        Write-Host "Lettre de lecteur invalide." -ForegroundColor Red
        exit
    }
}
# Fonction pour accorder des permissions sur un disque
function Grant-PermissionsToDrive {
    param($driveLetter)
    
    # Confirmation avant de changer les permissions
    $confirmChangePermission = Read-Host "Etes-vous sûr de vouloir changer les permissions de ${driveLetter}? (Oui/Non)"
    if ($confirmChangePermission -ne 'Oui') {
        Write-Host "Modification des permissions annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }

    # Vérifie si le module NTFSSecurity est installé, sinon l'installe
    if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
        Write-Host "Le module NTFSSecurity est nécessaire pour continuer. Installation en cours..." -ForegroundColor Yellow
        Install-Module -Name NTFSSecurity -Confirm:$false -Force
    }

    # Gestion d'erreur lors de l'installation du module
    if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
        Write-Host "Echec de l'installation du module NTFSSecurity. Exécution interrompue." -ForegroundColor Red
        return
    }

    # Essayer d'accorder les permissions et gérer les erreurs potentielles
    try {
        Add-NTFSAccess -Path "${driveLetter}:\\" -Account $env:USERNAME -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndFiles
        Write-Host "Permissions accordées avec succès." -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur lors de l'octroi des permissions. Exécution interrompue." -ForegroundColor Red
    }
}

# Vérification des privilèges d'administration
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Attention: Ce script n'est pas exécuté avec des privilèges d'administrateur." -ForegroundColor Yellow
    $response = Read-Host "Souhaitez-vous continuer malgré cela? (Oui/Non)"
    if ($response -ne 'Oui') {
        Write-Host "Exécution interrompue de modification des privilèges." -ForegroundColor Red
        exit
    }
} else {
    Write-Host "Ce script est exécuté avec des privilèges d'administrateur." -ForegroundColor Green
}
