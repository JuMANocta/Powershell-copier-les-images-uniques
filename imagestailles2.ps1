function Get-ExternalDrives {
    # return Get-Volume  | Where-Object { $_.DriveType -eq 'Removable' -and $_.FileSystem -eq 'FAT32' }
    return Get-Volume
}

function Show-ExternalDrives {
    param($drives)
    Write-Host "Disques amovibles disponibles:" -ForegroundColor Green
    foreach ($drive in $drives) {
        Write-Host ("Lettre: " + $drive.DriveLetter + "`t" + "Taille: " + $drive.SizeRemaining + "/" + $drive.Size + "`t" + "Type de système de fichiers: " + $drive.FileSystem) -ForegroundColor Cyan
    }
}

function Grant-PermissionsToDrive {
    param($driveLetter)
    
    # Demande de confirmation
    $confirmChangePermission = Read-Host "Etes-vous sûr de vouloir changer les permissions de ${driveLetter}? (Oui/Non)"
    if ($confirmChangePermission -ne 'Oui') {
        Write-Host "Modification des permissions annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }

    if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
        Write-Host "Le module NTFSSecurity est nécessaire pour continuer. Installation en cours..." -ForegroundColor Yellow
        Install-Module -Name NTFSSecurity -Confirm:$false -Force

        if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
            Write-Host "Echec de l'installation du module NTFSSecurity. Exécution interrompue." -ForegroundColor Red
            return
        }
    }

    try {
        Add-NTFSAccess -Path "${driveLetter}:\\" -Account $env:USERNAME -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndFiles
        Write-Host "Permissions accordées avec succès." -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur lors de l'octroi des permissions. Exécution interrompue." -ForegroundColor Red
        return
    }
}

function Get-FileHashMD5 {
    param($filePath)
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $hashBytes = $md5.ComputeHash([System.IO.File]::ReadAllBytes($filePath))
    return [BitConverter]::ToString($hashBytes) -replace '-'
}

function Select-Drive {
    $externalDrives = Get-ExternalDrives
    if (-not $externalDrives) {
        Write-Host "Aucun disque amovible trouvé." -ForegroundColor Red
        exit
    }
    Show-ExternalDrives -drives $externalDrives

    $selected = Read-Host "Entrez la lettre du disque que vous souhaitez utiliser"
    if ($externalDrives.DriveLetter -contains $selected) {
        return $selected
    }
    else {
        Write-Host "Lettre de lecteur invalide." -ForegroundColor Red
        exit
    }
}

$selectedDrive = Select-Drive

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Attention: Ce script n'est pas exécuté avec des privilèges d'administrateur." -ForegroundColor Yellow
    Write-Host "Il est possible que certaines opérations échouent en raison de restrictions d'accès." -ForegroundColor Yellow
    $response = Read-Host "Souhaitez-vous continuer malgré cela? (Oui/Non)"
    if ($response -ne 'Oui') {
        Write-Host "Exécution interrompue de modification des privilèges." -ForegroundColor Red
        exit
    }
}
else {
    Write-Host "Ce script est exécuté avec des privilèges d'administrateur." -ForegroundColor Green
    # demander à l'utilisateur s'il souhaite changer les permissions du disque
    $response = Read-Host "Souhaitez-vous changer les permissions du disque ${selectedDrive}? (Oui/Non)"
    if ($response -eq 'Oui') {
        Write-Host "Changement des permissions du disque ${selectedDrive} en cours..." -ForegroundColor Yellow
        Grant-PermissionsToDrive -driveLetter $selectedDrive
        Write-Host "Les permissions du disque ${selectedDrive} ont été modifiées." -ForegroundColor Green
    }
    else {
        Write-Host "Les permissions du disque ${selectedDrive} n'ont pas été modifiées." -ForegroundColor Yellow
    }
}

# Emplacement du fichier de log
$logFile = "log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Définition des variables pour les extensions de fichiers
$choixExtensions = @()
$imageExtensions = @("*.jpg", "*.jpeg")
$videoExtensions = @(".3g2", ".3gp", ".amv", ".asf", ".avi", ".drc", ".f4v", ".flv", ".m2v", ".m4p", ".m4v", ".mkv", ".mng", ".mov", ".mp2", ".mp4", ".mpe", ".mpeg", ".mpg", ".mpv", ".mxf", ".nsv", ".ogg", ".ogv", ".qt", ".rm", ".rmvb", ".roq", ".svi", ".vob", ".webm", ".wmv", ".yuv")
$audioExtensions = @(".aif", ".cda", ".mid", ".midi", ".mp3", ".mpa", ".ogg", ".wav", ".wma", ".wpl", ".m3u", ".flac", ".alac", ".aac", ".ac3", ".m4a", ".m4p", ".m4b", ".mogg", ".opus", ".ra", ".rm", ".raw", ".sln", ".tta", ".voc", ".vox", ".wv", ".8svx", ".webm")
#$imageExtensions = @(".ai", ".bmp", ".gif", ".ico", ".jpeg", ".jpg", ".png", ".ps", ".psd", ".svg", ".tif", ".tiff", ".cr2", ".nef", ".orf", ".sr2", ".raw", ".arw", ".crw", ".nrw", ".k25", ".heif", ".heic", ".indd", ".ai", ".eps", ".pdf", ".xrf", ".webp")
$documentExtensions = @(".doc", ".docx", ".pdf", ".txt", ".odt", ".ods", ".odp", ".xlsx", ".xls", ".ppt", ".pptx", ".rtf", ".csv", ".epub", ".mobi")
# Définition de la variable pour le dossier
$nomDossier = ""

# Permettre à l'utilisateur de choisir entre images videos ou audios
$choice = Read-Host "Quel type de fichiers souhaitez-vous copier? (Images(I)/Videos(V)/Audios(A)/Document(D)/Tous(T))"
switch ($choice) {
    'I' {
        $choixExtensions = $imageExtensions
        $nomDossier = "Images"
        break
    }
    'V' {
        $choixExtensions = $videoExtensions
        $nomDossier = "Videos"
        break
    }
    'A' {
        $choixExtensions = $audioExtensions
        $nomDossier = "Audios"
        break
    }
    'D' {
        $choixExtensions = $documentExtensions
        $nomDossier = "Documents"
        break
    }
    'T' {
        $choixExtensions = $imageExtensions + $videoExtensions + $audioExtensions
        $nomDossier = "All"
        break
    }
    default {
        Write-Host "Choix invalide. Exécution interrompue. END..." -ForegroundColor Red
        exit
    }
}
$destinationFolder = "${selectedDrive}:\UniqueFiles\$nomDossier"

# Enregistrement de l'heure de début
$startDateTime = Get-Date

Write-Host "Récupération des fichiers en cours..." -ForegroundColor Yellow

$files = Get-ChildItem -Recurse "${selectedDrive}:" -Include $choixExtensions -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "${destinationFolder}\*" }

$totalFilesBeforeHashing = $files.Count
$totalSizeBeforeHashing = ($files | Measure-Object -Property Length -Sum).Sum / 1MB

Write-Host "Filtrage des fichiers pour ne garder que les uniques..." -ForegroundColor Yellow

$hashTable = @{}
$uniqueFiles = $files | Where-Object {
    $hashString = Get-FileHashMD5 -filePath $_.FullName

    if ($hashTable.ContainsKey($hashString)) {
        $false
    }
    else {
        $hashTable[$hashString] = $true
        $true
    }
}

$totalFilesAfterHashing = $uniqueFiles.Count
$totalSizeAfterHashing = ($uniqueFiles | Measure-Object -Property Length -Sum).Sum / 1MB

# Demander à l'utilisateur si il souhaite changer le disque de destination
$choice = Read-Host "Souhaitez-vous changer le disque de destination? (Oui/Non)"
if ($choice -eq 'Oui') {
    $selectedDrive = Select-Drive
    $destinationFolder = "${selectedDrive}:\UniqueFiles$nomDossier"
}

# Vérification de l'espace disque avant de commencer la copie
$totalSizeRequired = ($uniqueFiles | Measure-Object -Property Length -Sum).Sum
$freeSpaceOnDrive = (Get-Volume -DriveLetter $selectedDrive).SizeRemaining

if ($totalSizeRequired -gt $freeSpaceOnDrive) {
    Write-Host "Espace insuffisant sur le disque. Exécution interrompue." -ForegroundColor Red
    exit
}

# Demandez à l'utilisateur s'il souhaite copier les fichiers uniques
Write-Host "Espace disque suffisant pour copier les fichiers uniques." -ForegroundColor Green
Write-Host "Nombre de fichiers avant hashage: $totalFilesBeforeHashing" -ForegroundColor Yellow

$choice = Read-Host "Vous êtes sur le point de copier $totalFilesAfterHashing fichiers pour un total de $totalSizeAfterHashing MB vers $destinationFolder. Etes-vous sûr? (Oui/Non)"

if ($choice -eq 'Oui') {
    Write-Host "Création du dossier destination..." -ForegroundColor Yellow

    # Gestion d'erreur pour la création du dossier
    try {
        if (-not (Test-Path $destinationFolder)) {
            New-Item -Path $destinationFolder -ItemType Directory
        }
    }
    catch {
        Write-Host "Erreur lors de la création du dossier de destination. Exécution interrompue." -ForegroundColor Red
        exit
    }

    Write-Host "Copie des fichiers en cours..." -ForegroundColor Yellow

    $index = 0
    $totalFiles = $uniqueFiles.Count
    foreach ($file in $uniqueFiles) {
        $index++
        $progress = ($index / $totalFiles) * 100
        Write-Progress -Activity "Copie des fichiers" -Status "$index sur $totalFiles" -PercentComplete $progress
        $destinationPath = Join-Path $destinationFolder $file.Name
        try {
            Copy-Item -Path $file.FullName -Destination $destinationPath -Force
        }
        catch {
            Write-Host "Erreur lors de la copie du fichier $($file.FullName). Chemin: $($file.FullName). Ce fichier sera ignoré." -ForegroundColor Yellow
        }
    }

    $copyMessage = "Les fichiers uniques ont été copiés dans $destinationFolder"
    Write-Host $copyMessage -ForegroundColor Green
}
else {
    $copyMessage = "Les fichiers n'ont pas été copiés."
    Write-Host $copyMessage -ForegroundColor Red
}

$logMessage = "Ecriture du fichier de log en cours..."
Write-Host $logMessage -ForegroundColor Magenta

# Enregistrement de l'heure de fin
$endDateTime = Get-Date

# Calcul du temps d'exécution
$duration = $endDateTime - $startDateTime

$logContent = @"
---
Date et heure de début: $startDateTime
Nombre de fichiers avant hashage: $totalFilesBeforeHashing
Taille totale avant hashage: {0:N2} MB

Nombre de fichiers après hashage: $totalFilesAfterHashing
Taille totale après hashage: {1:N2} MB

$copyMessage

Durée d'exécution: $duration
---
"@ -f $totalSizeBeforeHashing, $totalSizeAfterHashing

# Écriture du log dans le fichier
Add-Content -Path $logFile -Value $logContent

# Affichage des résultats
Write-Output $logContent

$endMessage = "Fin du script. Bye !"
Write-Host $endMessage -ForegroundColor Green