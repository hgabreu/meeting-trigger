Meeting-trigger
==========================

This script monitors for apps reading from the mic (using pulseaudio pacmd) to trigger custom automations.
It can be setup to run as systemd user service (i.e. does not require root privileges).

### Usage examples:

- Pause/Play your music automatically as you enter and leave meetings
- Set your "on call" status in any/all your chatting apps when you enter meetings in any platform
- Toggle a red (smart) light outside your home-office to indicate that you're on a call or not
  - There's a sample script provided for lights that have [ifttt](https://ifttt.com) integration.
    That is, they can be turned on/off through an applet that can be triggered using webhooks (an url)

Sample scripts are create automatically when you first run the [configuration](#configuration).

Got more ideas? Maybe some sample action script? Please share and we'll add them here.

Installation
================

### Archlinux:
You can install it from [AUR](https://aur.archlinux.org/packages/meeting-trigger) with you preferred aur-helper or "manually" with:
```
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/meeting-trigger.git
cd meeting-trigger
makepkg -fsri
```
There's also a pre-built package on the releases here on github.

### Ubuntu:
You can download the pre-build `.deb` package from the [latest release](https://github.com/hgabreu/meeting-trigger/releases/latest).

Or clone this repo and build it with the following:
```
sudo apt install git checkinstall
git clone git@github.com:hgabreu/meeting-trigger.git
cd meeting-trigger
sudo ./build.ubuntu.sh
```
meeting-trigger depends on only very basic packages that your system should already have.
But if for any reason the procedure above fails, check/install all the dependencies with the following
```
sudo apt install bash coreutils findutils grep pulseaudio-utils sed debianutils
```


Configuration
================

Run the `EditConfig` option to have the config and samples created the first time:
```
meeting-trigger EditConfig
```
The config file will be located at: `~/.config/meeting-trigger/meeting-trigger.conf`

Sample trigger-scripts will be located at: `~/.config/meeting-trigger/scripts/`

You can change this location on the config file.

Adjust the scripts to setup your custom automations.

Running
================

Test that your setup works
```
meeting-trigger ListAppsUsingMic
meeting-trigger Trigger on
meeting-trigger Trigger off
```

Enable to start on boot and start it now (no need for sudo)
```
systemctl --user enable meeting-trigger
systemctl --user start meeting-trigger
```

Copyright
================
- License: [Gnu General Public License Version 3](LICENSE)
- This script is based on [pulse-autoconf](https://eomanis.duckdns.org/permshare/pulse-autoconf/) by eomanis
- Copyright &copy; 2022 - Henrique Abreu <hgabreu@gmail.com>

