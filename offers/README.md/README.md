# Hyprland Empty‑Workspace Dock (Waybar)

A second Waybar bar that shows a macOS‑style dock **only on empty Hyprland workspaces** (workspaces with zero windows).  
Designed for NixOS, built and managed entirely with Claude Code.

## Overview
- **Behaviour**: Appears on the top‑left of the screen when the current workspace has no windows; hides as soon as any window is opened on that workspace.
- **Content**: 12 large application launcher icons, ordered by usage frequency. Users can pin apps (keep always visible) and add/remove shortcuts.
- **Style**: A single rounded glassy background with blur behind the icons.

## Visual design
- **Position**:  
  - Offset: `4 cm` from the top, `3 cm` from the left.  
  - Expands horizontally to accommodate exactly 12 icons (icon size ~64px, generous padding).  
- **Background**: One seamless piece of “glass” that spans the full width of the icon row.  
  - Rounded corners (e.g., 24px border‑radius).  
  - Background‑blur + semi‑transparent colour (`rgba(255,255,255,0.15)` with `backdrop-filter: blur(20px)`).  
  - Subtle border (`1px solid rgba(255,255,255,0.2)`) to enhance the glass effect.  
- **Icons**:  
  - Large (64x64 px or bigger), evenly spaced.  
  - Active/inactive states indicated by subtle glow or opacity change.  
  - Pin status shown with a small dot or pin emblem.  

## Requirements
- **OS**: NixOS with Hyprland compositor.
- **Bar**: Waybar (installed & configured via Nix).
- **IPC**: `hyprctl` for workspace/window queries.
- **Runtime**: Bash or Python for the monitoring daemon.

## Implementation approach (ideas)
1. **Empty‑workspace detection**  
   - Use `hyprctl clients` or `hyprctl workspaces` in a loop to check the number of windows on the active workspace.  
   - When count = 0, show the secondary Waybar; when > 0, hide it.

2. **Dual Waybar instance**  
   - Run a second Waybar process with a dedicated config (`empty-dock/config.jsonc`) and style (`empty-dock/style.css`).  
   - Use `hyprctl dispatch` or `kill` to start/stop the instance (or toggle visibility via `pkill -USR1 waybar` with specific bar name if supported).  
   - Alternative: a single Waybar with a highly dynamic module that hides/shows the entire bar based on a custom signal.

3. **App launcher & usage tracking**  
   - Maintain a database (simple JSON file) of launched applications with launch counts and pin flags.  
   - Use `exec-once` scripts to intercept `.desktop` file launches or monitor `hyprctl dispatchers exec`.  
   - Dynamically regenerate the Waybar configuration to reflect the top 12 apps, respecting pinned entries.

4. **Pinning / add / remove**  
   - Right‑click (or long‑press) on an icon opens a context menu (use `wlrctl` or a small popup) for pin/unpin, remove from list.  
   - A “+” icon at the end opens a launcher (rofi, wofi, or a custom dmenu) to add new apps.  
   - All changes written to the usage database, triggering a config rebuild.

5. **Styling**  
   - Pure CSS using Waybar’s `#custom-*` or `#taskbar` styling.  
   - The glass effect is achieved via `backdrop-filter: blur(12px)` – requires a Waybar revision that supports CSS3 (current git master does). If not, simulate with `background-image` using a blurred screenshot of the wallpaper (less dynamic but feasible).

6. **Integration with NixOS**  
   - Provide a Nix module (or `home‑manager` module) that installs the scripts, starts the daemon, and optionally enables the custom Waybar styling.  
   - Ensure all dependencies (wlrctl, rofi, jq, etc.) are declared.

## What Claude Code must do
- Read this `README.md` thoroughly.  
- Wait for the user to place a `RESUME.md` file in the same directory.  
- When `RESUME.md` appears, fill it with a detailed, step‑by‑step implementation plan that respects:
  - Modularity and scalability.
  - A debugging policy (logs, dry‑runs, unit tests).
  - Incremental delivery (start with detection, then bar styling, then launcher logic).  
- Execute the plan by building all necessary files and configurations.

## Deliverables (expected)
- `empty-dock/waybar-monitor.sh` (or `.py`) – daemon that tracks workspaces.
- `empty-dock/config.jsonc` – Waybar config for the dock.
- `empty-dock/style.css` – Glassy dock styling.
- `empty-dock/apps.json` – Usage database (initially empty).
- `empty-dock/update-launchers.sh` – Script that regenerates Waybar modules from the database.
- Nix expression (`default.nix` or `flake.nix`) to package everything.
- Systemd user unit (or Hyprland exec‑once) to run the daemon.
