# Brewmanager

A Droplet for [Droppy](https://getdroppy.app), built with
[DroppyKit](https://getdroppy.app/docs/droppykit).

## Developing

```bash
droppykit run        # open it in Droppy's Settings panel
droppykit build      # produce Brewmanager.droplet
droppykit validate   # the checks a submission runs
droppykit submit     # open the submission form, filled in from this checkout
```

## With a coding agent

Open this folder in Claude Code, Codex or Cursor. `AGENTS.md` is the brief
they read first, and `.mcp.json` / `.cursor/mcp.json` connect the DroppyKit
MCP server, which gives them the build, the checks, pictures of every surface
and an install into Droppy Playground as tools. Codex registers the server
once per Mac: `codex mcp add droppykit -- path/to/droppykit/Scripts/droppykit mcp`.
Run `droppykit agent` again after moving this folder or the SDK checkout.

## Before submitting

- Replace `Brewmanager.icon` with real artwork, in Icon Composer.
- Replace `Assets/Creator.png` with your own square, unrounded mark.
- Fill in `summary`, `description`, `creator` and `source` in `droplet.json`.
- Push this repository, then `droppykit submit`: it opens
  [getdroppy.app/submit-droplet](https://getdroppy.app/submit-droplet) with the
  repository, the commit and the id filled in.
