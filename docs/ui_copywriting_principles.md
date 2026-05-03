# UI Copywriting Principles

Good interface copy trusts the surrounding context—navigation titles, icons, layout, and platform conventions—to carry much of the meaning. Strings should add only information the user cannot infer at a glance: a clear action (**Save**, **Edit**), a short state label (**Empty**, **Submitted**), or a specific constraint (**Name required**). Avoid restating what the screen already announces; long explanatory sentences belong in onboarding, empty-state bodies, or help, not on every repeated control. Prefer **economy**: one distinctive word often beats a full clause when paired with visuals. Maintain **consistent terminology**: one canonical term for custom categories, drafts, orders, and dishes across tabs and sheets reduces cognitive load and makes localization predictable. Reserve length for genuine ambiguity or risk (errors, destructive actions, permissions); elsewhere, aim for scannable noun or verb phrases rather than complete sentences.

**Examples**

- **Prefer** *Edit* over *Edit this dish* when the row or card already identifies the item.
- **Prefer** *Custom* or *Category* in a labeled field over *Custom category* when the form section title supplies *Category*.
- **Prefer** a short empty-state headline (*No orders yet*) plus optional supporting line, instead of *From Menu — your active order shows up here*.
- **Prefer** *Submit* on a primary button when the preceding screen states what is being submitted; avoid *Submit your changes to the menu* unless you need to disambiguate from other submit actions on the same flow.
- **Prefer** reusing the same string key for the same concept app-wide rather than near-synonyms that drift in tone and length across screens.

When reviewing `Localizable.xcstrings` (or any copy pass), ask: *If I remove this phrase, does the user lose information not already given by the UI?* If not, shorten or drop it. If yes, keep the minimum words that carry that information.
