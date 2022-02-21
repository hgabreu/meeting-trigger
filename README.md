Meeting-trigger
==========================

This script runs as a systemd user daemon monitoring for apps reading from the mic (using pulseaudio pacmd) to trigger custom automations. 

Installation
=============
```
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/meeting-trigger.git
cd meeting-trigger
makepkg -fsri
```

Configuration
================

```
meeting-trigger EditConfig
```

You can check and edit sample action scripts on `~/.config/meeting-trigger/scripts/`


Running
================

Test that your setup works
```
meeting-trigger DetectMicState
meeting-trigger Trigger on
meeting-trigger Trigger off
```

Enable to start on boot and start it now

```
systemctl --user enable meeting-trigger
systemctl --user start meeting-trigger
```

Copyright
=========
- License: [Gnu General Public License Version 3](LICENSE)
- This script is heavly based on pulse-autoconf by eomanis at https://eomanis.duckdns.org/permshare/pulse-autoconf/
- Copyright &copy; 2022 - Henrique Abreu <hgabreu@gmail.com>

