# Script PowerShell pour la déduplication des images
## Description
Ce script permet de repérer et de copier les images uniques depuis un disque amovible vers un nouveau dossier. Il génère également un fichier de journalisation détaillant les opérations effectuées.

## Pré-requis
Windows PowerShell.
Droits d'administrateur pour le fonctionnement optimal.
Module NTFSSecurity pour les opérations liées aux permissions NTFS.
## Fonctionnalités
1. Animation de chargement : Une animation est affichée pendant les opérations de longue durée pour informer l'utilisateur que le script est en cours d'exécution.
2. Sélection de disque : L'utilisateur peut choisir un disque amovible à partir d'une liste.
3. Vérification des droits d'administrateur : Avise l'utilisateur si le script n'est pas exécuté avec des droits d'administrateur.
4. Permissions NTFS : Accorde automatiquement les permissions nécessaires sur le disque amovible.
5. Détection des doublons : Utilise un hash MD5 pour détecter et filtrer les images uniques.
6. Copie des images uniques : Les images uniques sont copiées dans un nouveau dossier UniqueFiles sur le disque amovible.
7. Journalisation : Les détails des opérations sont enregistrés dans un fichier de log pour une future référence.
## Utilisation
1. Exécutez le script dans PowerShell.
2. Suivez les instructions à l'écran pour sélectionner un disque et effectuer la déduplication.
3. Consultez le fichier de log généré pour voir les détails des opérations effectuées.
## Note
Pour un fonctionnement optimal, il est recommandé d'exécuter ce script avec des droits d'administrateur.

### TODO
#### Modifier la logique de Hashage des fichiers :
Le calcul du hash pour chaque fichier est potentiellement lent, surtout pour des fichiers volumineux. Si vous avez beaucoup de fichiers à traiter, cela pourrait ralentir considérablement le script. Une optimisation possible serait de comparer d'abord les tailles des fichiers avant de les hacher. Si deux fichiers ont des tailles différentes, ils sont forcément différents, donc pas besoin de les hacher.