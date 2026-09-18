# Omameter

A super-minimal Omarchy plugin: four 1px meters on the outer edge of the menubar.

```
bezel
  CPU  ████████░░░░░░░░░░░░
  RAM  ██████░░░░░░░░░░░░░░
  NET  ██░░░░░░░░░░░░░░░░░░
  GPU  ████████████░░░░░░░░
menubar
```

Each meter is one pixel thick. No chrome, no labels, no extra reserved space. The strip sits between the screen bezel and the Omarchy bar and follows the bar when you drag it:

| Bar position | Meters |
| --- | --- |
| Top | 4px strip above the bar (CPU nearest the bezel) |
| Bottom | 4px strip below the bar (CPU nearest the bezel) |
| Left / right | 4px strip on the outer edge (CPU nearest the bezel) |

Meters, from the bezel inward: **CPU**, **RAM**, **network**, **GPU RAM**. Fill length is usage. Color heats from the meter’s hue toward red as the value climbs. Clicks pass through.

## Install on Omarchy

Omameter is a git repo with `manifest.json` at the root. From a clone of this repository:

```sh
omarchy plugin add /path/to/omameter --enable
```

Or from a published git URL:

```sh
omarchy plugin add https://github.com/samohtnt/mini-omameter.git --enable
```

The installer clones into `~/.config/omarchy/plugins/troy.omameter`, validates the manifest, and enables the panel. `keepLoaded` mounts it for the session, so the meters appear as soon as the shell loads the plugin. If the strip is missing after enable:

```sh
omarchy-shell shell rescanPlugins
omarchy-restart-shell
```

### Install by hand

```sh
mkdir -p ~/.config/omarchy/plugins
cp -r . ~/.config/omarchy/plugins/troy.omameter
omarchy-shell shell rescanPlugins
omarchy plugin enable troy.omameter
```

Do not put a symlink in the plugin folder. Omarchy rejects plugins that contain symlinks.

## Hide / show

The meters stay up while the plugin is enabled. To tuck them away without removing it:

```sh
omarchy-shell shell hide troy.omameter
omarchy-shell shell summon troy.omameter '{}'
```

If the menubar autohides, the meters hide with it.

## Remove

```sh
omarchy plugin remove troy.omameter
```

## What it reads

| Meter | Source |
| --- | --- |
| CPU | `/proc/stat` idle/total deltas |
| RAM | `/proc/meminfo` (`MemTotal` − `MemAvailable`) |
| Network | `/proc/net/dev` on the default-route interface, scaled against a decaying peak (1 MB/s floor) |
| GPU RAM | sysfs `mem_info_vram_used` / `mem_info_vram_total`; `nvidia-smi` only if sysfs has no VRAM counters |

No extra packages. Python 3 is used as a long-running sampler inside `omarchy-shell`. Plugins run unsandboxed in that process — read the files before you enable them.

## Develop

```sh
python3 -m unittest discover -s tests -v
```

On an Omarchy machine, after copying into `~/.config/omarchy/plugins/troy.omameter`, saving a QML file reloads the plugin. You can also force it:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/troy.omameter
omarchy-shell shell rescanPlugins
```
