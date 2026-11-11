# kora_fuel agent guide

kora_fuel provides native vehicle fuel consumption, petrol-pump refuelling, EV charging stations and LegacyFuel-compatible exports for Kora FiveM servers. Layout: `config.lua` (options and kora_lib config schema), `shared/` (station normalisation and fuel/pricing helpers), `client/` (consumption, service menu, charger props, blips), `server/` (validated purchases), `locales/`, `test/` (plain-Lua smoke tests) and `tests/` (kora_qa Gherkin scenarios).

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first for an overview of features, configuration, commands, exports, events and database usage.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.
