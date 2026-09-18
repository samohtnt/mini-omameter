# Omameter

A super-minimal Omarchy plugin with one meter on each screen edge: CPU at the top, RAM on the left, root filesystem on the right, and network at the bottom.

```
                 ← CPU →
               ┌────────┐
         RAM ↑  │ screen │  DISK ↑
               └────────┘
              ← UP / DOWN →
```

CPU, RAM, and root filesystem are three pixels thick. The bottom network meter is one pixel thick, with one background pixel below it: upload occupies the left half and download the right half. Upload grows leftward and download grows rightward from the screen center. The network halves share a decaying peak, so their lengths show the relative rates. The network track uses the theme's muted color to remain visible at idle; all four edge strips use the bar's background color. CPU grows outward from the horizontal center; RAM and root filesystem grow upward from the bottom edge. Meter fills use the active Omarchy theme: accent for CPU and download, bar text for RAM and upload, and muted for filesystem. As usage rises, each fill blends toward the theme’s bar active color. Clicks pass through.

Colors are bound to Omarchy's live theme palette, so a theme switch updates the fills, tracks, markers, and bar-matched backgrounds without restarting the shell.

The fills rise smoothly over 280 ms and fall over 900 ms. A thin theme-colored high-water mark stays at the latest peak for 1.4 seconds, then fades over 4.2 seconds. The top CPU bar shows the mark at both ends of its center-out fill; each network half shows one mark at its outer end, and the side bars show it at the upper end.

On the filesystem meter, the marker rests at the current usage level and flashes when the root filesystem's block device completes reads or writes. If `/` is on a network or virtual filesystem without a local block device, usage still works but the I/O flash is unavailable.

## Install on Omarchy

Omameter is a git repo with `manifest.json` at the root. From a clone of this repository:

```sh
omarchy plugin add /path/to/omameter --enable
```

Or from a published git URL:

```sh
omarchy plugin add https://github.com/samohtnt/mini-omameter.git --enable
```

The installer clones into `~/.config/omarchy/plugins/troy.omameter`, validates the manifest, and enables the panel. `keepLoaded` mounts it for the session, so the meters appear as soon as the shell loads the plugin.

To keep windows clear of all four strips, reserve three pixels at the top, left, and right, and two at the bottom of each monitor in `~/.config/hypr/monitors.lua`. Add `reserved_area` to the existing `hl.monitor` rule for each output, preserving its mode, position, and scale:

```lua
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto",
  reserved_area = { top = 3, bottom = 2, left = 3, right = 3 } })
```

The empty output matches monitors without a more specific rule. If your configuration has output-specific rules, add the same `reserved_area` to those rules.

Hyprland places a top bar below the CPU strip and keeps tiled windows clear of the side and bottom strips.

If the strip is missing after enable:

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
| Download / upload | `/proc/net/dev` receive and transmit bytes on IPv4/IPv6 default-route interfaces, or all non-loopback interfaces when there is no default route; shared decaying peak (1 MB/s floor) |
| Root filesystem | `os.statvfs("/")`, used space as a percentage of used plus user-available space |
| Root disk activity | `/proc/self/mountinfo` identifies the root block device; `/proc/diskstats` reports completed reads and writes |

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
