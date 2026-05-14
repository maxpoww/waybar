# CLAUDE.md

This file contains persistent instructions for Claude Code when working on this project.

## 1. Token economy
- Keep prompts as short and focused as possible.
- Reuse context from `README.md` and any `RESUME.md` that appears later – do not repeat their full content unless necessary.
- When asking questions, prefer concise, actionable responses.

## 2. Superpowers plugin
- Install and activate the **superpowers** plugin before starting any coding task.
- If the plugin is not detected, prompt the user to set it up (e.g., via the MCP marketplace or a custom MCP server).  
- Confirm the plugin is active in the session before making changes.

## 3. Proactive use of skills
- Identify repetitive patterns (config generation, module templating, IPC calls) and encapsulate them in reusable **skills**.
- Create skills on the fly and document them in the project (e.g., inside `.claude/skills/`).
- Update the skill documentation as the project evolves.

## 4. Agents for complex tasks
- Spawn subagents when a task can be split into independent pieces (e.g., one agent for Hyprland IPC logic, another for Waybar CSS styling, another for the pinning/launcher management).
- Use the `Task` tool to dispatch agents and aggregate their results.

## 5. Project idea & RESUME.md
- This project aims to create a **second Waybar bar** that appears **only on empty Hyprland workspaces** (no open windows).  
  It acts as a glassy dock showing the 12 most‑used applications, with pinning and add/remove capabilities.
- The detailed specification lives in `README.md` in this directory.  
  **Read `README.md` first** to understand the full scope.
- A file named `RESUME.md` will be generated later (by the user or by you).  
  When `RESUME.md` appears, you **must** use it to write a self‑guiding plan:
  - Outline the implementation architecture step‑by‑step.
  - Describe the debugging policy (logging, unit tests, incremental testing).
  - Ensure the design is scalable and modifiable from the start.
  - Keep `RESUME.md` updated after every major change.
