# App Store Connect Submission · 食单 / Kitchen (en-US)

Backup locale for overseas markets · v1.0 · Updated 2026-05-05

---

## A. App Information

Name: `Kitchen: Family Menu`  (20/30); alt: `Kitchen — Family Menu` / `Family Kitchen Menu` — src: `kitchen/kitchen/Info.plist:8` (display name 食单)
Subtitle: `Plan, order, cook together`  (26/30); alt: `Shared menu for the whole family` / `Order from your home menu`
Bundle ID: `cain.com.kitchen` — src: `kitchen.xcodeproj/project.pbxproj:357`
Primary Language: `Simplified Chinese (zh-Hans)`
Primary Category: `Food & Drink`; Secondary: `Lifestyle` — inferred
Content Rights: `© 2026 {entity}` — ⚠️ replace with real legal entity
Age Rating: `4+`

Age questionnaire (answer + reason):
- Cartoon/realistic violence, sexual content, nudity, profanity, alcohol/tobacco/drugs, mature themes, horror, simulated gambling, medical info, unrestricted web access: **all None**
- UGC / user-to-user: **Yes (mild)** — members of the same private kitchen see each other's dishes/orders; no public chat
- Unencrypted transmission: **No** — HTTPS only (src: `Info.plist:6`)
- Data used for tracking: **No**

---

## B. This Version (1.0)

Support URL: `https://evilirving.github.io/family-concept` — src: `Views/Settings/PageView.swift:16`
Marketing URL: ⚠️ TBD
Copyright: `© 2026 {entity}`
Contact (name/phone/email): ⚠️ TBD

Promotional Text (≤170):
> A shared menu for the people who eat at your table. Snap dishes, place orders, track cooking status, and auto-build the grocery list.

Keywords (≤100, ranked by intent):
> family menu,recipe,cook,meal plan,grocery list,kitchen,household,shared,roommate,dinner

Description (≤4000):
> Kitchen turns your family's everyday meals into a shared, orderable menu. The cook stops asking "what should we eat tonight?" — the eaters stop staring into the fridge.
>
> What you can do
> • Build the menu: take a photo or pick from your library; the app uses on-device Vision to auto-cut the dish from its background and create a calm, consistent cover. Add a name, category, and ingredients.
> • Order at home: each member taps the dishes they want; the app rolls them into the current order. The cook moves each item through "to cook → cooking → done" — everyone sees the status.
> • Shopping list: the active order is auto-aggregated into a single grocery list you can share before walking into the store.
> • Meal history: every finished round is archived, so you can look back at what your household actually ate this week.
> • Multi-member: invite by code, separate admin and member roles, rotate the invite anytime.
>
> Designed for iOS
> • Native SwiftUI, no fancy transitions
> • Soft, green-leaning card UI; status colors stay quiet
> • Full Dark Mode, Dynamic Type, and Reduce Motion support
> • Localized in English, Simplified Chinese, Traditional Chinese, Japanese, Korean
>
> Privacy
> • No tracking. No third-party analytics or ad SDKs.
> • HTTPS and Apple-standard crypto only.
> • Your data belongs to you and the people you invite. Sign out anytime.
>
> Pricing
> • Free tier holds up to 10 dishes — enough for a small household.
> • One-time in-app purchase to unlock 50 dishes or unlimited dishes. No subscription. No renewal.

What's New (v1.0):
> First release of Kitchen:
> • Build a shared family menu with photo-based dish covers (auto subject extraction)
> • Invite-code multi-member kitchens with role management
> • Live order status flow and auto grocery list
> • Meal history archive
> • One-time IAP to expand the dish quota

---

## C. App Privacy (questionnaire)

Summary: no tracking, no third-party analytics/ad SDKs; only `CryptoKit` is imported (src: `Models/Entitlement.swift:2`). All collected data is linked and used solely for App Functionality.

- Contact Info: **Not collected**
- Health & Fitness: **Not collected**
- Financial Info: **Not collected** (handled by App Store)
- Location: **Not collected**
- Sensitive Info: **Not collected**
- Contacts: **Not collected**
- User Content · Photos/Videos: **Collected**, linked, no tracking, App Functionality (dish covers) — src: `PrivacyInfo.xcprivacy:27-38`
- User Content · Other (dish names/ingredients/orders/kitchen name): **Collected**, linked, no tracking, App Functionality — src: `PrivacyInfo.xcprivacy:41-52`
- Browsing History: **Not collected**
- Search History: **Not collected** (in-menu search is local filter only)
- Identifiers · User ID (server account): **Collected**, linked, no tracking, App Functionality — src: `PrivacyInfo.xcprivacy:55-66`
- Identifiers · Device ID / IDFA: **Not collected**
- Purchases: **Not collected** (StoreKit handled by Apple)
- Usage Data: **Not collected**
- Diagnostics: **Not collected** (no Crashlytics/Sentry)
- Other · Name (nickname): **Collected**, linked, no tracking, App Functionality — src: `PrivacyInfo.xcprivacy:13-24`
- Other · Session tokens: **Collected**, linked, no tracking, App Functionality — src: `PrivacyInfo.xcprivacy:69-80`

---

## D. App Review Information

Contact (name/phone/email): ⚠️ TBD
Sign-in required: **Yes**
Demo Account: username `reviewer_demo` / password ⚠️ TBD — src: `Views/Onboarding/AuthForm.swift`

Review notes:
> Kitchen is a private family-menu and ordering tool. There is no public chat, no UGC broadcast — content is only visible to the creator and members invited via code.
>
> Critical path:
> 1. Onboarding: register or sign in
> 2. Create a kitchen, or join one with an invite code
> 3. Menu tab → add dishes (camera/library; on-device Vision extracts the subject)
> 4. Orders tab → tap dishes to build the current order; states flow "to cook → cooking → done"
> 5. Finishing the round archives the order to history
>
> Permissions: Camera only when user explicitly takes a dish photo; Photo Library only when user picks a cover.
> IAP: two non-consumable products (kitchen.dishes.essentials, kitchen.dishes.unlimited) expand per-kitchen dish quota. No subscription.

---

## E. Export Compliance / Encryption

Uses encryption: **Yes — Apple-standard only**
`ITSAppUsesNonExemptEncryption`: `false` (recommend declaring in Info.plist)
Evidence: `URLSession` + HTTPS only (src: `Info.plist:6`); only crypto call is `CryptoKit.SHA256` for AppAccountToken derivation (src: `Models/Entitlement.swift:99-115`) — covered by "hash only" + "Apple platform standard API" exemptions

---

## F. Content Rights / Third-Party Content

Contains third-party copyrighted content: **No** (dish images are user-supplied)

---

## G. Advertising Identifier (IDFA)

Used: **No** (no `AppTrackingTransparency` / `ASIdentifierManager` / `GADMobileAds`, full-repo grep verified); leave **all** IDFA usage checkboxes unchecked

---

## H. Screenshots & Previews

- iPhone 6.9" 1320×2868 (required, 3–10)
- iPhone 6.5" 1284×2778 or 1242×2688 (required, 3–10)
- iPad 13" 2064×2752 (if iPad kept; current `TARGETED_DEVICE_FAMILY = "1,2"` — confirm)
- App Previews (optional): up to 3 per size, 15–30 s, ≤500 MB, H.264/HEVC

Suggested order: Main menu / Add dish / Current order / Shopping list / Meal history / Settings (members·invite·upgrade)

⚠️ Previous mockup `app_store_mockup_6_9_1320x2868.png` deleted — regenerate

---

## I. In-App Purchases (both Non-Consumable, no subscription)

Product 1: ID `kitchen.dishes.essentials` · Ref `Kitchen — 50 Dishes` · Display `50 Dishes` · Price ⚠️ suggest Tier 2 / US $1.99 · Family Sharing ON · Promo 1024×1024 ⚠️ TBD — src: `Models/Entitlement.swift:37`
Product 2: ID `kitchen.dishes.unlimited` · Ref `Kitchen — Unlimited Dishes` · Display `Unlimited Dishes` · Price ⚠️ suggest Tier 10 / US $9.99 · Family Sharing ON · Promo 1024×1024 ⚠️ TBD — src: `Models/Entitlement.swift:38`

Product 1 desc: `Expand your kitchen to hold up to 50 dishes — comfortably enough for a typical household. One-time purchase, kept forever.`
Product 2 desc: `Remove the dish-count limit on your kitchen. Add as many dishes as you'd like. One-time purchase, kept forever.`

---

## J. TestFlight

Beta description: `Kitchen Beta: family menu and ordering tool. This round focuses on dish-image subject extraction, IAP entitlement sync, and multi-member refresh.`
Feedback email: ⚠️ TBD
Marketing URL: leave empty or fill once site exists
Privacy Policy URL: `https://evilirving.github.io/family-concept`
Sign-in info: same as section D demo account

---

## K. Localization

Shipped: `en` (source) / `ja` / `ko` / `zh-Hans` (primary) / `zh-Hant` — src: `Localizable.xcstrings`
Per-locale fields: name, subtitle, promo text, description, keywords, what's new, screenshots (per-locale uploadable)
⚠️ This file covers zh-Hans / en only; ja/ko/zh-Hant should be **hand-localized**, not machine-translated (especially keywords & subtitle)

---

## ✅ Open Items Checklist

- [ ] Replace placeholder copyright entity ("Kitchen")
- [ ] Review contact: name / phone / email
- [ ] Real demo account with stable password
- [ ] Marketing URL
- [ ] Expand `https://evilirving.github.io/family-concept` to cover Privacy + Support + **Account Deletion**
- [ ] Add `ITSAppUsesNonExemptEncryption = false` to Info.plist
- [ ] Confirm iPad support; if no, change `TARGETED_DEVICE_FAMILY` back to `"1"`
- [ ] Generate fresh screenshots for every required size
- [ ] Decide final price tiers for both IAP products
- [ ] Produce 1024×1024 promo art for each IAP product
- [ ] Hand-localize ja / ko / zh-Hant copy (do not machine-translate keywords)
- [ ] **Critical:** `Views/Settings/PageView.swift` only exposes "Sign Out" — **no in-app account-deletion path**. Apple guideline 5.1.1(v) requires one. Add before submission or expect rejection.
