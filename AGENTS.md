# kora_fuel agent guide

kora_fuel provides native vehicle fuel consumption, petrol-pump refuelling, EV charging stations and LegacyFuel-compatible exports for Kora FiveM servers. Layout: `config.lua` (options and kora_lib config schema), `shared/` (station normalisation and fuel/pricing helpers), `client/` (consumption, service menu, charger props, blips), `server/` (validated purchases), `locales/`, `test/` (plain-Lua smoke tests) and `tests/` (kora_qa Gherkin scenarios).

## Documentation

Feature and behaviour changes must update the matching docs in the same change.

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first: it is the hub with the feature overview and a documentation map. Layout: `installation.md` (install steps, manifest, start order), `how-to-use.md` (purchase flow, consumption, charging stations), `commands.md` (kora_fuel registers none), `api/` (`client-exports.md`, `compat.md` for the LegacyFuel/qb-fuel/ps-fuel/cdn-fuel aliases, `configuration.md` for every `config.lua` option), and topic pages (`refuelling-and-charging.md`, `consumption.md`, `blips.md`, `events.md`, `troubleshooting.md`). Update the page that owns the topic.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.

## Shared contribution standards

Read [CONTRIBUTING.md](CONTRIBUTING.md) before editing. Humans and agents follow
the same Kora standards and self-contained local Lua checks. Preserve the domain
constraints above and in module guides; record policy conflicts explicitly.

Copyright © 2026 Kora Framework (new contribution guidance).
