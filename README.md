# tasks

CLI that lists your ClickUp tasks in colored terminal tables, joined with
your local `ws` (workspaces CLI) dev workspaces — with clickable buttons to
create or open a workspace straight from the table.

```
Ongoing (2)
╭───┬─────────────────────────────┬──────┬─────────────┬──────────┬──────────────────────────╮
│ # │ Task                        │ Prio │ Status      │ List     │ Workspace                │
├───┼─────────────────────────────┼──────┼─────────────┼──────────┼──────────────────────────┤
│ 1 │ Payment integration         │      │ in progress │ Backlog  │ ● CU-8abc123_payment-in… │
│ 2 │ Fix booking code sync       │ HIGH │ in progress │ Backlog  │ ⊕ create workspace       │
╰───┴─────────────────────────────┴──────┴─────────────┴──────────┴──────────────────────────╯
```

On a terminal:
- task names are clickable links to the ClickUp ticket
- workspace names open that workspace in VS Code (via its `.code-workspace`)
- **⊕ create workspace** runs `ws create <slug>` in a Terminal window
- workspace dots use the same accent colors as `ws list`
- status colors and grouping are configurable

Piped output is plain text (no colors/buttons) and includes a URL column.
Row state is written to `~/.cache/anny-tasks/last-list.json` (row index →
task id/url/slug), so other tools can resolve "task #N".

## Layout

```
bin/tasks                    the CLI (node, zero dependencies)
handler/ws-url-open          dispatcher for anny-ws:// URLs (bash)
handler/handler.applescript.in  source for the URL-handler app
install.sh                   one-shot setup (PATH symlink + URL handler)
config.json.example          config template
config.json                  your config (gitignored — holds the API token)
build/                       generated app bundle (gitignored)
```

## Setup

1. `cp config.json.example config.json` and fill in your values (below).
2. `./install.sh` — symlinks `tasks` into `~/.local/bin` and builds +
   registers the `anny-ws://` URL handler for the clickable buttons.
3. Verify: `tasks` prints your table; `open "anny-ws://ping/hello"` pops a
   Terminal window.

Requirements: macOS, node ≥ 18, the `ws` workspaces CLI, VS Code (`code`).

First click on a button: VS Code asks to open the external URI (allow), and
macOS asks once to let the handler control Terminal (allow). Rerunning
`install.sh` re-signs the app, which re-triggers that consent once.

## Config

All user-specific values live in `config.json` (gitignored; nothing personal
is hardcoded in the scripts):

| key | meaning |
| --- | --- |
| `token` | ClickUp personal API token (`pk_...`, avatar → Settings → Apps). The `CLICKUP_API_TOKEN` env var takes precedence. |
| `assignee` | numeric ClickUp user ID whose tasks are listed (`GET /api/v2/user`) |
| `lists` | ClickUp lists to query: `[{ "id": "...", "label": "..." }]` |
| `workspacesRoot` | absolute path to the `ws` workspaces dir (`<root>/<slug>/<slug>.code-workspace`) |
| `statusGroups` | display groups in order: `{ "key", "title", "statuses": [{ "name", "color"? }] }`. Colors: red, green, yellow, blue, magenta, cyan, dim. Tasks in unlisted statuses appear under "Other". |

## The anny-ws:// URL scheme

`install.sh` compiles `handler/handler.applescript.in` into
`build/AnnyWsHandler.app` (dispatcher path baked in, ad-hoc signed,
machine-local — hence gitignored) and registers it with LaunchServices.
Clicked URLs go to `handler/ws-url-open`, which allows only:

- `anny-ws://create/<slug>` → `ws create <slug>` in a Terminal window
- `anny-ws://open/<slug>` → opens the workspace's `.code-workspace` in
  VS Code (silent)
- `anny-ws://ping/<x>` → echo, for sanity checks

URLs carry data, never commands; slugs are validated against
`^CU-[a-z0-9]+_[a-z0-9-]+$`. Any app that can emit a hyperlink can reuse the
scheme.

### Troubleshooting

Error -1743 with *no* consent prompt means macOS (TCC) can't attribute the
app — almost always a broken code signature (editing the app's Info.plist
after `osacompile` breaks the seal; `install.sh` re-signs to fix this, and
sets `NSAppleEventsUsageDescription`, without which macOS never shows the
prompt at all). Reset a stuck denial with:

```
tccutil reset AppleEvents co.anny.ws-url-handler
```
