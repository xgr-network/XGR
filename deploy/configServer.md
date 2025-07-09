SSH-Key auf dem privaten Rechner generieren (Windows, ohne Adminrechte)

PowerShell öffnen (keine Adminrechte nötig):

Drücke Win + S, gib "PowerShell" ein, und öffne es

SSH-Key erzeugen:

ssh-keygen -t rsa -b 4096 -C "xgrchain@privatrechner"

Wenn du gefragt wirst, wohin der Key gespeichert werden soll: Einfach Enter drücken (Standardpfad wird verwendet: C:\Users\<Name>\.ssh\id_rsa)

Wenn du nach einer Passphrase gefragt wirst, kannst du leer lassen (nur Enter), falls du keine zusätzliche Sicherung willst

Public Key anzeigen (zum Einfügen in den Server):

Get-Content $env:USERPROFILE\.ssh\id_rsa.pub

Den kompletten Output (beginnt mit ssh-rsa AAAAB3...) kopieren

Root-Passwort auf einem Server zurücksetzen (Strato / Rettungssystem)

1. Server in den Recovery-Modus (Rettungssystem) starten:

Im Strato Cloud Panel: Server öffnen → Aktionen → "Recovery-System starten"

2. Per VNC-Konsole einloggen (Zugangsdaten stehen im Panel)

3. Partition des Systems finden und mounten:

fdisk -l                     # zeigt alle Partitionen
mount /dev/sda2 /mnt         # Beispiel: passende Partition einhängen

(ggf. anpassen, z. B. /dev/md0 oder /dev/nvme0n1p2)

4. In das System wechseln:

chroot /mnt /bin/bash

5. Neues Root-Passwort setzen:

passwd

Neues Passwort eingeben (erscheint nicht beim Tippen)

Mit Enter bestätigen, erneut eingeben

6. Neustarten:

exit
reboot

Nach dem Neustart kannst du dich wieder als root per VNC oder über SSH (wenn Key hinterlegt wurde) anmelden.

Grundkonfiguration eines Ubuntu 22.04 Servers (XGRChain Mainnet - Node 1)

1. System aktualisieren und Pakete installieren

sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl build-essential unzip wget tmux ufw

Hinweis: Falls du dabei folgende Meldung siehst:

"Pending kernel upgrade... 5.15.0-142 → 5.15.0-143"

Dann gilt:

Schließe den Dialog mit Enter

Führe danach folgenden Befehl aus, um den neuen Kernel zu aktivieren:

sudo reboot

2. Go installieren (Version 1.21.6)

wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz
echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
source ~/.profile

Go-Version prüfen:

echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

go version


#### 3. Fork von polygon-edge klonen und builden

> **Hinweis:** Wechsle vorher vom `root`-Benutzer zu deinem normalen Benutzer `xgradmin`:
> ```bash
> su - xgradmin
> ```
> 
> Stelle sicher, dass dein SSH-Key oder GitHub-Zugang dort eingerichtet ist.

> **Achtung:** In folgendem Befehl steht `<DEIN-GITHUB-NAME>` für deinen GitHub-Accountnamen, nicht den lokalen Linux-Benutzer!
```bash
git clone https://github.com/<DEIN-GITHUB-NAME>/xgrchain.git
cd xgrchain

git checkout xgrchain-v0.1    # auf den gewünschten Branch wechseln
go mod tidy
go build -o xgrchain .

Starthilfe anzeigen:

./xgrchain --help

Ab hier kannst du den Genesis-Block generieren und den Node konfigurieren (folgt als nächster Abschnitt).

