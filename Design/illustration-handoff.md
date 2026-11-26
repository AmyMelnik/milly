# Illustration handoff (for ChatGPT image generation)

## How to use this

1. In ChatGPT, attach 3 existing PNGs as style references:
   `ing-broccoli`, `basketfull-front` and `ing-salmon` (in `MealPrep/Assets.xcassets/Ingredients/`).
2. Paste the **master prompt** once, then ask for items one by one with the short prompt from the tables below.
3. Generate one object per image. Ask for a redo if it adds a background, shadow, outline or text.

### Master prompt (paste first)

> Match the attached illustrations exactly in style. Hand-painted gouache / marker look with visible
> brush texture, flat matte colour, slightly uneven edges, no black outlines, no drop shadow, no gradient
> background, no text or labels. One object only, centred, seen from the front or a slight 3/4 angle.
> Transparent background, square 1024×1024 PNG. The object fills about 70% of the canvas (leave ~15%
> empty margin on every side). Warm, natural, appetising colours that sit well on a warm off-white
> (#FAF7F2) app background.

### Export specs

| | |
|---|---|
| Size | 1024×1024 from ChatGPT → downscale to **512×512** PNG, RGBA |
| Fill | drawing ≈ 70% of the square (the app assumes this for every image) |
| Background | fully transparent |
| Name | `ing-<name>.png` for products, `state-<name>.png` for states, `station-<name>.png` for stations |

---

## 1. Missing products (ingredients)

Today many ingredients fall back to a "close enough" picture (avocado shows broccoli, beef shows mince,
cucumber shows courgette). These would cover the most common gaps. **P1** = shows up in most plans.

| Pri | File | What to draw | Replaces today |
|---|---|---|---|
| P1 | `ing-avocado` | one whole avocado + one half with the pit | broccoli |
| P1 | `ing-cucumber` | one cucumber, slightly curved | courgette |
| P1 | `ing-aubergine` | one glossy aubergine | courgette |
| P1 | `ing-cauliflower` | one cauliflower head with green leaves | broccoli |
| P1 | `ing-greenbeans` | small bundle of green beans | broccoli |
| P1 | `ing-lettuce` | head of romaine / leafy lettuce | spinach |
| P1 | `ing-herbs` | small bunch of fresh parsley/coriander tied with string | spinach |
| P1 | `ing-chili` | two red chili peppers | bell pepper |
| P1 | `ing-ginger` | knobbly ginger root | onion & garlic |
| P1 | `ing-beans` | can of kidney/black beans (no label text) | chickpeas |
| P1 | `ing-lentils` | small paper bag of red lentils, a few spilled | chickpeas |
| P1 | `ing-noodles` | nest of dried egg noodles | pasta |
| P1 | `ing-quinoa` | bowl/bag of couscous or quinoa grains | rice |
| P1 | `ing-bread` | crusty sourdough loaf | wraps |
| P1 | `ing-beef` | raw steak on a butcher paper | minced meat |
| P1 | `ing-sausage` | two raw sausages / chorizo | minced meat |
| P1 | `ing-whitefish` | white fish fillet (cod) on paper | salmon |
| P1 | `ing-tuna` | open tin of tuna | salmon |
| P1 | `ing-feta` | white block of feta | cheese |
| P2 | `ing-mozzarella` | mozzarella ball | cheese |
| P2 | `ing-cream` | small carton of cooking cream / crème fraîche tub | yoghurt |
| P2 | `ing-peas` | open pea pod with peas | broccoli |
| P2 | `ing-corn` | corn cob with husk | chickpeas |
| P2 | `ing-cabbage` | red cabbage, one half cut | broccoli |
| P2 | `ing-kale` | bunch of curly kale | spinach |
| P2 | `ing-beetroot` | two beetroots with stems | carrots |
| P2 | `ing-orange` | orange + one segment | lemon & lime |
| P2 | `ing-honey` | honey jar with wooden dipper | sauce |
| P2 | `ing-mustard` | small mustard jar | sauce |
| P2 | `ing-pesto` | jar of green pesto | sauce |
| P2 | `ing-tahini` | jar of tahini / hummus bowl | sauce |
| P2 | `ing-peanutbutter` | jar of peanut butter | nuts |
| P2 | `ing-vinegar` | small vinegar bottle | olive oil |
| P2 | `ing-sesame` | small pile of sesame seeds | nuts |
| P2 | `ing-tempeh` | block of tempeh | tofu |
| P3 | `ing-banana` | two bananas (breakfast plans) | — |
| P3 | `ing-berries` | small punnet of berries | — |
| P3 | `ing-apple` | one apple | — |
| P3 | `ing-frozenveg` | bag of frozen mixed vegetables, frosty | broccoli |
| P3 | `ing-salt` | salt pinch bowl / grinder | spice jar |

---

## 2. State illustrations

Places where the app shows a state with a stand-in ingredient, a plain SF Symbol, or nothing.

| Pri | File | Where it's shown | What to draw |
|---|---|---|---|
| P1 | `state-plan-failed` | Wizard → "Something went wrong" (now a tomato tin) | wooden spoon next to a tipped-over pot with a small spill |
| P1 | `state-plan-ready` | Plan just generated / plan header | three glass meal-prep containers, filled with rice, greens and salmon, lids leaning against them |
| P1 | `state-plan-deleted` | Plan view "This plan was deleted" (now trash icon) | empty meal-prep container with its lid off |
| P1 | `state-no-plans` | Home with no plans yet | empty wicker basket (same basket as `ing-basket`) with one leek peeking out |
| P1 | `state-cart-added` | Picnic: everything added to the cart | paper grocery bag full of produce, a green tag tied on the handle |
| P1 | `state-cart-partial` | Picnic: some items failed | the same basket with one tomato rolled out beside it |
| P1 | `state-product-not-found` | Picnic: no product matches a search | magnifying glass over a single lonely carrot |
| P1 | `state-searching` | Picnic: searching products | magnifying glass on its own |
| P1 | `state-offline` | Any network error (Claude or Picnic) | delivery paper bag folded shut, with a small cloud above |
| P1 | `state-invalid-key` | Claude key rejected / onboarding "Connect Claude" (now soy sauce) | old brass key on a kitchen string loop |
| P2 | `state-picnic-login` | Onboarding "Log in to Picnic", "Log in to order" (now basket) | doorstep with a paper bag and an envelope |
| P2 | `state-code-sent` | Picnic SMS/email code step | envelope with a small folded note sticking out |
| P2 | `state-kitchen-photos` | Zero-waste "What's in your kitchen" (now milk) | open fridge door with a few leftovers on the shelves |
| P2 | `state-camera-denied` | Camera access refused | closed fridge with a sticky note on it |
| P2 | `state-tweak` | Tweak sheet "Describe a change" (now spice jar) | wooden spoon stirring a pot, a chili and a pinch of spice falling in |
| P2 | `state-swap` | "Swap this component" sheet | two small bowls side by side (rice and potatoes) |
| P2 | `state-favourite` | Favourites section / empty favourites | recipe card with a hand-painted star |
| P2 | `state-checkout` | "Open Picnic to check out" | paper receipt curling, next to a full bag |
| P3 | `state-saved-plans` | Settings → Saved plans (now rice) | stack of three meal-prep containers |
| P3 | `state-welcome` | Onboarding welcome hero (alternative to the cluster) | wicker basket overflowing with mixed groceries |

---

## 3. Wizard step and option art

| Pri | File | Where | What to draw |
|---|---|---|---|
| P1 | `state-time` | Wizard → cooking time step | classic red kitchen timer |
| P1 | `state-portion-s` | Hunger/portion option: small | small bowl, half full |
| P1 | `state-portion-m` | Hunger/portion option: medium | medium bowl, full |
| P1 | `state-portion-l` | Hunger/portion option: large | big bowl, heaped |
| P2 | `ing-lowcarb` | Diet "Low carb" (now tomatoes) | avocado half + egg + leafy greens, small group |
| P2 | `state-avoid` | Wizard → "What to leave out" (now nuts) | a few nuts and a shrimp with a hand-drawn line through them (no red circle icon) |
| P2 | `state-wishes` | Wizard → "Any wishes" (now lemon & lime) | handwritten recipe card with a pencil (no readable text) |
| P3 | `state-review` | Wizard → review step | open notebook with a pencil and a lemon |

---

## 4. Cooking stations (replace SF Symbols in the cooking timeline)

Shown small (≈18–28 pt), so keep shapes bold and simple.

| File | What to draw |
|---|---|
| `station-oven` | small oven tray with roasting vegetables |
| `station-stove` | frying pan with a wooden spatula |
| `station-board` | wooden cutting board with a knife and a halved carrot |
| `station-bowl` | ceramic mixing bowl with a whisk |
| `station-fridge` | glass container with lid, cold (a few frost dots) |

---

## After generating

- Drop each PNG into `Assets.xcassets/Ingredients/` as its own image set (same layout as the existing ones).
- New products also need a `case` in `Food.swift`, a `realSizeCM`, and keywords in the match table
  (e.g. move "avocado" from broccoli to `.avocado`).
- State, wizard and station art needs small view changes to use it; send them back and I'll wire them in.
