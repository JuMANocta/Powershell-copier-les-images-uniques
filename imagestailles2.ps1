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
