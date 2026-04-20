# Flow Design System — Claude Code Plugin Marketplace

> **Ship Flow UI at the speed of a conversation.**
> AI-assisted component lookup, design token resolution, icon search, theme comparison, and live validation — inside Claude Code, powered by MCP.

The official plugin marketplace for the [Flow Design System](https://flow.estl.edu.sg). Install once and get first-class design system awareness directly inside Claude Code.

---

## What you get

The **flow-builder** plugin gives Claude Code live access to the Flow Design System:

| Capability | What it does |
|---|---|
| Component docs | Look up props, slots, variants, sub-components, and usage examples for any `@flow/core` component (stable or unstable). |
| Token resolution | Search design tokens by name, CSS variable, or Tailwind class — across colour, spacing, typography, radius, shadow, and border. |
| Icon search | Search and filter 545+ curated icons from `@flow/icons` by category. |
| Theme support | Inspect product theme palette mappings, or compare two themes side-by-side. |
| Usage validation | Verify Tailwind classes and CSS variables map to valid design tokens, with suggested alternatives for invalid ones. |
| Skill workflows | Drive full end-to-end flows (`prototype`, `setup`, `theme`, `build`) that combine MCP, the Flow docs, and the project's own `globals.css`. |

---

## Installation

There are two ways to get started. Pick the one that matches where you are right now:

- **Windows** → [Using the Windows install script](#using-the-windows-install-script)
- **macOS, Linux, or already have Node.js and the `@flow` registry configured?** → [Using the Claude Code plugin marketplace](#using-the-claude-code-plugin-marketplace)

### Using the Windows install script

> **Windows 10+ with winget required.** New to Claude Code on Windows? See the [Windows setup guide](https://code.claude.com/docs/en/setup#set-up-on-windows).

A PowerShell script that installs mise, Node.js, configures the `@flow` npm registry, and sets up the Flow Builder skills for Claude Code.

```powershell
irm https://raw.githubusercontent.com/flow-design-system/marketplace/refs/heads/main/setup-personal.ps1 | iex
```

> If you get an execution policy error, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` first.

The script is safe to re-run — it skips anything already installed.

After it finishes, open a new PowerShell window and run `claude` to get started.

### Using the Claude Code plugin marketplace

If you already have Node.js and the `@flow` npm registry configured, install the plugin directly through Claude Code's native marketplace flow.

**Prerequisite — configure the `@flow` registry once:**

```bash
npm config set @flow:registry https://sgts.gitlab-dedicated.com/api/v4/projects/60257/packages/npm/
```

**Then, inside Claude Code:**

```
/plugin marketplace add flow-design-system/marketplace
/plugin install flow-builder@flow-marketplace
```

Your slash commands will be `/flow-builder:setup` and `/flow-builder:build` (namespaced plugin form).

---

## Skills

Beyond raw MCP tool access, the plugin bundles Claude Code skills that drive full workflows end-to-end. Pick the skill that matches your intent:

| User intent | Skill |
|---|---|
| Start from scratch (no project yet) | `prototype` |
| Add Flow to an existing project | `setup` |
| Change brand colours / create a theme | `theme` |
| Build or modify UI components | `build` |

### `/flow-builder:prototype` — Scaffold a new project

Scaffolds a brand-new Vite + React + TypeScript project with Flow pre-configured end-to-end. Detects your system package manager (npm/pnpm/yarn/bun), runs `create vite`, installs dependencies, delegates to `setup` for Flow configuration, strips Vite boilerplate, and starts the dev server to verify everything renders.

**Example prompt:**

> "Spin up a new Flow project called dashboard-poc."

### `/flow-builder:setup` — First-time project bootstrap

First-time bootstrap of `@flow/core`, `@flow/design-tokens`, and `@flow/icons` into a new or existing React project. Detects the framework (Vite, Next.js, Remix, plain React), flags Tailwind v3/v4 conflicts, configures Tailwind v4 CSS imports, optionally adds a product theme, and wraps the app in `DesignSystemProvider`. Skips projects that already have Flow installed.

**Example prompt:**

> "Set up Flow in this Vite + Tailwind v4 project and add the `product-a` theme."

### `/flow-builder:theme` — Create or modify a brand theme

Generates a `theme.css` file with CSS variable overrides for brand, accent, and optionally neutral colour scales. Two paths: pick a built-in palette (30+ primitives like teal, indigo, amber) or supply a custom hex and get a full 12-step scale generated via `@flow/core`. Accent is automatically paired with brand and checked for accessibility (perceptual distinction, lightness contrast, WCAG AA text legibility).

**Example prompt:**

> "Use teal as the brand colour and create a custom theme."

### `/flow-builder:build` — Build UI with the design system

Sources components, icons, and theme-aware tokens via `@flow/mcp`; reconciles against the project's `globals.css` for local overrides and custom `@utility` declarations; follows design references (foundations, components, accessibility, anti-patterns) for visual rigour. Asks for clarification on underspecified requests before building.

**Example prompt:**

> "Build a dashboard page with a sidebar, stat cards, and a recent activity list. Use the `product-a` theme tokens."

> **Slash command names depend on how you installed.** The plugin marketplace gives you the namespaced form (`/flow-builder:setup`, `/flow-builder:build`, etc.). The bootstrap install script gives you the dash form (`/flow-setup`, `/flow-build`, etc.). Both paths share the same skills and MCP server — only the command name differs. See the [`@flow/builder` README](https://sgts.gitlab-dedicated.com/wog/moe/moeestl/moe-estl/design-system/design-system/-/blob/main/packages/@flow/builder/README.md#choosing-an-install-mode) for a side-by-side comparison.

---

## Contributing

### Adding a plugin

1. Fork this repo and create a branch.
2. Add a plugin entry to [`.claude-plugin/marketplace.json`](./.claude-plugin/marketplace.json). Each entry needs at minimum a `name` and a `source` — see the [marketplace schema docs](https://code.claude.com/docs/en/plugin-marketplaces.md) for the full spec. Source types include npm packages, GitHub repos, Git URLs, and local paths.
3. Validate your changes from inside Claude Code:
   ```
   /plugin validate .
   ```
4. Test the plugin locally:
   ```
   /plugin marketplace add ./path/to/your/checkout
   /plugin install your-plugin@flow-marketplace
   ```
5. Open a pull request. The `@flow-design-system/maintainers` team is automatically requested for review.

### Reporting issues

File bugs or feature requests in the [design-system monorepo issue tracker](https://sgts.gitlab-dedicated.com/wog/moe/moeestl/moe-estl/design-system/design-system/-/issues).

---

## Learn more

- [Flow Design System docs](https://flow.estl.edu.sg)
- [`@flow/builder` reference](https://sgts.gitlab-dedicated.com/wog/moe/moeestl/moe-estl/design-system/design-system/-/blob/main/packages/@flow/builder/README.md) — full install, scope, and lifecycle documentation
- [`@flow/mcp`](https://sgts.gitlab-dedicated.com/wog/moe/moeestl/moe-estl/design-system/design-system/-/blob/main/packages/@flow/mcp/README.md) — the MCP server powering the plugin
- [Claude Code plugins](https://code.claude.com/docs/en/plugins.md) — official plugin docs
