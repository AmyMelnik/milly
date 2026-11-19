# Meal Prep → Picnic

A personal iOS app (SwiftUI, iOS 17+) that:

1. **Plans**: a step-by-step wizard asks one question per screen (meals, eating style, portion size, how many proteins/carbs/veggies/sauces, cooking time, what to avoid, wishes). Claude (`claude-opus-5-5`) then designs a *modular* plan. It isn't tied to days: it shows the prepped modules, suggested combinations, how many ways they can be mixed, a separate cooking-order recipe (a timed timeline showing which steps run in parallel) and a grocery list with Dutch Picnic search terms.
2. **Tweaks**: you can swap any one component, or describe a change ("spicier", "no rice"). Claude revises only that part and keeps the meals and groceries consistent.
3. **Orders**: it logs in to Picnic (NL), finds a product for each grocery and lets you pick a different one. It then adds everything to your Picnic cart. You check out in the Picnic app.

## Setup

1. Open `MealPrep.xcodeproj` in Xcode.
2. To run it on your iPhone:
   - In Xcode → Settings → Accounts, add your Apple ID (a free one works).
   - Connect the iPhone with a cable, unlock it and tap **Trust**.
   - On the iPhone: Settings → Privacy & Security → **Developer Mode** → on, then restart it.
   - In Xcode, select the MealPrep target → Signing & Capabilities → Team: your Apple ID.
   - Pick your iPhone at the top of the window and press ▶︎. The first time, on the iPhone go to Settings → General → VPN & Device Management and trust your developer profile.
   - With a free Apple ID the app stops opening after 7 days; press ▶︎ again to refresh it.
3. On first launch, onboarding asks for:
   - an Anthropic API key from console.anthropic.com, which is checked with Anthropic before it's saved;
   - your Picnic login, including the SMS or email code if Picnic asks. You can skip this and log in when you first order.
4. Change either later with the gear on the landing screen, or ••• → Settings on a plan.

## TestFlight

TestFlight builds stay installable for 90 days (instead of 7 with a free Apple ID) and install over the air.

1. Join the Apple Developer Program (paid, yearly) with your Apple ID, and add that Apple ID in Xcode → Settings → Accounts.
2. In App Store Connect → Apps → **+** → New App: platform iOS, bundle ID `app.mealprep.personals8vi4q` (register it if it isn't listed), and any unique name. "Meal Prep" alone is probably taken; the name on your home screen stays "Meal Prep".
3. In Xcode, select the MealPrep target → Signing & Capabilities → Team: your developer team.
4. Choose **Any iOS Device** as the destination → Product → **Archive** → **Distribute App** → **TestFlight & App Store** → Upload.
5. When the build has processed (about 10–30 min), add yourself under TestFlight → Internal Testing, then install the **TestFlight** app on your iPhone and accept the invite.

Already in place: app icon, privacy manifest (`PrivacyInfo.xcprivacy`), the export-compliance answer (standard HTTPS only), version 1.0 (build 1). Bump the build number for every new upload. Internal testing needs no App Review; inviting external testers would, and the unofficial Picnic API could be a problem there.

## Security

- The Anthropic key and the Picnic session token are stored only in the iOS Keychain (`Services/Keychain.swift`): readable only while the iPhone is unlocked (`WhenUnlockedThisDeviceOnly`), never synced to iCloud Keychain and never in backups. They are never written to files, UserDefaults or logs.
- Your Picnic password is MD5-hashed (Picnic's own scheme) and sent only to Picnic at login. It is never stored.
- Keychain items survive deleting an app, so a fresh install wipes any left-over key or session on first launch.
- Saved plans are written with iOS file protection, which keeps them encrypted while the phone is locked.
- The key goes only to `api.anthropic.com`; the Picnic token goes only to Picnic's storefront API.
- Debug builds accept a `-PreviewSkipOnboarding` launch argument for previewing screens in the Simulator. It is compiled out of release builds.

## Look

Minimal warm-white layout with hairline cards and black buttons. Big titles use **Gambetta** (Indian Type Foundry, free via Fontshare, ITF Free Font License), with tightened line height via `TitleText` in `Views/Theme.swift`, and everything else uses **Open Sans** (SIL Open Font License). Both licenses are in `FontLicenses/`. The ingredient illustrations in `Assets.xcassets/Ingredients` come from the Figma file and add the colour.

## Files

- `Services/ClaudePlanner.swift`: the prompt, the JSON schema (structured outputs), key validation and the Messages API call.
- `Services/PicnicClient.swift`: Picnic login (with 2FA), search and add-to-cart.
- `Services/Keychain.swift`: secure storage for the key and Picnic session.
- `Services/ShoppingList.swift`: matches grocery items to Picnic products and adds them to the cart.
- `Services/AppStore.swift`: app state, onboarding status, saved plans.
- `Views/Theme.swift`: colours, fonts, cards, buttons, inputs.
- `Views/OnboardingView.swift`: welcome, connect Claude, log in to Picnic.
- `Views/WizardView.swift`: the question-by-question wizard and the loading screen.
- `Views/PlanView.swift`: plan screen with Combos, Cooking order and Groceries tabs, plus tweak/swap.
- `Views/ShopViews.swift`: Picnic login form, product matching, cart, settings.
- `Models/Food.swift`: picks an ingredient illustration from English or Dutch ingredient names.

## Caveats

- Picnic has **no official API**. This app uses the endpoints the Picnic app itself uses, as documented by the open-source `python-picnic-api2` (the library Home Assistant uses). Picnic can change them at any time, and using them may go against Picnic's terms. Keep it for personal use.
- Every plan generation or revision is one paid Claude API call.
