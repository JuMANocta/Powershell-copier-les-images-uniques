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
# Fonction pour calculer le hash MD5 d'un fichier (déjà définie précédemment)
function Get-FileHashMD5 {
    param($filePath)
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $hashBytes = $md5.ComputeHash([System.IO.File]::ReadAllBytes($filePath))
    return [BitConverter]::ToString($hashBytes) -replace '-'
}

# Sélection du disque par l'utilisateur
$selectedDrive = Select-Drive

# Définition des extensions de fichiers pour les différents types de médias
$imageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp")
$videoExtensions = @("*.mp4", "*.avi", "*.mov", "*.mkv")
$audioExtensions = @("*.mp3", "*.wav", "*.aac", "*.flac")
$documentExtensions = @("*.doc", "*.docx", "*.pdf", "*.txt", "*.xlsx", "*.pptx")

# Choix du type de fichiers à copier
$choice = Read-Host "Quel type de fichiers souhaitez-vous copier? (Images(I)/Videos(V)/Audios(A)/Documents(D)/Tous(T))"
switch ($choice) {
    'I' { $choixExtensions = $imageExtensions }
    'V' { $choixExtensions = $videoExtensions }
    'A' { $choixExtensions = $audioExtensions }
    'D' { $choixExtensions = $documentExtensions }
    'T' { $choixExtensions = $imageExtensions + $videoExtensions + $audioExtensions + $documentExtensions }
    default {
        Write-Host "Choix invalide. Exécution interrompue." -ForegroundColor Red
        exit
    }
}
$startDateTime = Get-Date
# Recherche des fichiers uniques sur le disque sélectionné
$files = Get-ChildItem -Recurse "${selectedDrive}:" -Include $choixExtensions -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\UniqueFiles\*" }

$hashTable = @{}
$uniqueFiles = $files | Where-Object {
    $hashString = Get-FileHashMD5 -filePath $_.FullName
    if (-not $hashTable.ContainsKey($hashString)) {
        $hashTable[$hashString] = $true
        $true
    }
    else {
        $false
    }
}
# Définition de l'emplacement du fichier de log
$logFile = "log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Vérification de l'espace disque disponible
$totalSizeRequired = ($uniqueFiles | Measure-Object -Property Length -Sum).Sum
$freeSpaceOnDrive = (Get-Volume -DriveLetter $selectedDrive).SizeRemaining
if ($totalSizeRequired -gt $freeSpaceOnDrive) {
    Write-Host "Espace insuffisant sur le disque. Exécution interrompue." -ForegroundColor Red
    exit
}

# Copie des fichiers uniques dans le dossier de destination
if (-not (Test-Path $destinationFolder)) {
    New-Item -Path $destinationFolder -ItemType Directory
}
foreach ($file in $uniqueFiles) {
    $destinationPath = Join-Path $destinationFolder $file.Name
    try {
        Copy-Item -Path $file.FullName -Destination $destinationPath -Force
    }
    catch {
        Write-Host "Erreur lors de la copie du fichier $($file.FullName)." -ForegroundColor Yellow
    }
}

# Enregistrement du log
$endDateTime = Get-Date
$duration = $endDateTime - $startDateTime
$logContent = @"
Date et heure de début: $startDateTime
Nombre de fichiers uniques copiés: $($uniqueFiles.Count)
Durée d'exécution: $duration
Emplacement des fichiers copiés: $destinationFolder
"@

Add-Content -Path $logFile -Value $logContent

# Affichage des informations finales
Write-Host "Copie terminée. Les fichiers uniques ont été copiés dans $destinationFolder" -ForegroundColor Green
Write-Host "Détails enregistrés dans le fichier de log : $logFile" -ForegroundColor Green