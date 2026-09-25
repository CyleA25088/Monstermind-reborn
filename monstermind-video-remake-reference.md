# MonsterMind remake reference — video-derived design notes

Source video: [MonsterMind (Facebook) Gameplay Part 1](https://www.youtube.com/watch?v=Kh5Ppd0at74)

Video length: approximately 9:30. These notes record what is visibly supported by the video; unclear text and unseen systems are marked as uncertain rather than invented.

## 1. Core game concept

MonsterMind is a Facebook-era, isometric city-management and city-destruction game. The player builds and maintains a small town, balances population and defenses, then deploys monsters or weapons to destroy target structures in timed attack scenarios. Progress is presented through tutorial prompts, objectives, rewards, scores, stars, and a leaderboard/share result screen.

The demonstrated loop is:

1. Inspect a compact isometric city.
2. Repair or construct buildings.
3. Balance homes, businesses, and defensive structures so the population system works.
4. Receive an incoming-attack warning or mission objective.
5. Select a monster/weapon from the bottom deck.
6. Deploy it onto a highlighted route/target area.
7. Watch the monster travel and damage buildings; use bombs or attacks with area-of-effect risk.
8. Complete the objective, receive score/rewards/stars, and continue to the next city.

## 2. Camera, world, and presentation

- Fixed 3D/isometric camera; no visible free camera movement in this video.
- Square/rectangular playfield floating in a large green grass field.
- Roads form a visible grid and guide monster movement.
- Towns contain red-roof homes, larger civic/commercial buildings, trees, walls/fences, construction sites, rubble/craters, parked vehicles, signs, and small decorative objects.
- Buildings sit on shallow foundations with soft shadows and bright cartoon materials.
- The playfield is framed by a HUD at the top and a card/deck/action tray at the bottom.
- A large background title/wordmark is visible at the edge of the world in several shots (“BLOW…” / “MUDTOW…” appears to be level branding or a city name; exact text is unclear).
- Visual style: cheerful, toy-like, saturated casual-game 3D with exaggerated destruction and cartoon character callouts.

## 3. HUD and persistent UI

Top bar, left to right as visible in different shots:

- A coin/metal-looking resource with a large numeric balance.
- A small ticket/energy-like resource with a number.
- A blue flask/beaker meter with a number and horizontal fill.
- A red/orange monster or attack resource icon with a number.
- A purple circular currency/resource.
- Envelope icon for messages.
- Green gear icon for settings.
- In some shots a green monster icon with a count.

Other persistent controls:

- Left-side circular control with a curved-arrow/refresh-like icon.
- Small left-side square button that changes between contextual menus.
- Bottom-center tab row. Visible categories include a star/objective tab, building-related tabs, defensive/weapon tabs, and a blue-highlighted selected tab; exact icon meanings should be inferred from behavior during implementation.
- Bottom cards show selectable buildings/monsters, lock or level badges, resource costs, and small production/attack statistics.
- A red square button on the right side of the tray appears to be a destructive attack/weapon category.
- Hover/tap tooltips appear above cards with unit/building name, health or damage, cost, and timing values.

## 4. Tutorial and guidance language

The game uses a monochrome cartoon adviser with speech bubbles, yellow/orange tutorial cards, blinking arrows, and green confirmation buttons. Visible or mostly legible tutorial messages include:

- Repair the two damaged buildings and tap them as before.
- Send in the monsters; follow the highlighted path/area.
- Defense is critical; build a gun nest to protect the city.
- Balance population. The tutorial compares too many businesses/guns with too few homes against too many homes with too few guns; the desired state is balanced population support.
- Place down a bomb carefully; it damages anything in the blast radius.
- Follow the blinking arrows / click where the arrows indicate.
- A later prompt encourages increasing population.

Tutorial presentation to reproduce:

- Adviser portrait at lower left.
- White speech bubble with black text and a green question-mark help button.
- Center modal cards with orange header, all-caps title, simple illustrations, close button, and green “NICE!”/“NEXT”-style button.
- Large animated dotted/blue arrows and turquoise route overlays.
- Yellow exclamation balloons over buildings needing attention.

## 5. Buildings and world objects observed

Observed or strongly identifiable:

- Small red-roof residential homes, often in rows.
- Larger blue/gray civic building that appears to be the town hall or central civic target.
- Larger multistory commercial/civic building with orange/brown facade.
- Gas station with a large “GAS” sign.
- Commercial building with a prominent “Shop” sign.
- Circular purple/gray commercial or civic building.
- Defensive gun nest / machine-gun emplacement.
- Under-construction building with scaffolding.
- Damaged/blackened buildings, burning structures, rubble, and circular craters.
- Roads with gray pavement and light lane markings.
- Low stone walls/fences around portions of the map.
- Trees: conifers and rounded deciduous trees.
- Pink flowering ornamental tree.
- Roadside signs, including a green exit-style sign.
- Small vehicles and street props.
- Balloons with purple exclamation marks marking interactable or damaged buildings.

Buildings appear to have state changes: intact, selected, under construction, damaged/burning, destroyed/rubble, and repair-needed.

## 6. Monsters, weapons, and combat behavior

### Giant Ape

The clearest unit shown is a large brown/black ape-like monster. It:

- Is selected from a bottom card labeled “GIANT APE” (legibility is high enough to treat this name as reliable).
- Is deployed onto a highlighted turquoise route/area.
- Walks along roads toward targets.
- Attacks buildings at close range.
- Produces red floating damage numbers; one visible hit reads approximately “414”.
- Appears in groups during the town-hall mission.
- Is large enough to overlap streets/buildings and cast a prominent shadow.

### Other combat elements

- A green monster is visible at the left edge during a later attack; exact species/name is not legible.
- A purple beam/projectile or energy effect appears near the commercial area during the town-hall attack.
- Bomb icon/weapon is shown in the first mission. Its tooltip explicitly warns about area damage to anything in the blast radius.
- Machine Gun Nest is shown as a defensive building/card. Its tooltip visibly includes “MACHINE GUN NEST” and a health value around 300; other stat digits are too small to trust.
- Turrets/defensive structures are referenced by the adviser and appear as small emplacements around the city.
- Turquoise overlays show legal movement/target lanes or attack reach before deployment.
- Red warning triangles/exclamation markers indicate threats or buildings under attack.

Combat should feel like a directed attack rather than a conventional real-time shooter: choose a unit, place it, then observe autonomous movement and attacks while the timer/resource system runs.

## 7. Mission beats visible in the video

### Opening tutorial, roughly 0:00–1:30

- Small city with damaged buildings marked by colorful balloons.
- Player repairs buildings by selecting them.
- Player opens the monster deck and selects Giant Ape.
- Monster is sent along a route and destroys/attacks city structures.
- Defensive construction is introduced with Machine Gun Nest.
- Population balance tutorial appears.
- Incoming attack warning and building construction/damage states are shown.

### Town-hall attack, roughly 1:45–3:00

- Mission objective panel reads “DESTROY THE TOWN HALL.”
- City has more commercial variety: gas station, shop, circular building, homes, civic structure, roads, and trees.
- Several Giant Apes are deployed along turquoise highlighted lanes.
- The town hall burns and takes damage while monsters move through the town.
- Mission-complete result panel appears around 2:57.

Result panel details:

- Header: “CITY COMPLETE!”
- Left side: “TOTAL SCORE” with visible score approximately 43,335.
- Three-star rating row; one star is visibly filled in the sampled frame.
- Rewards include a blue/teal currency icon with “50” and a second reward with “1000”.
- Buttons: “RETRY” and a green “SHARE THE LOVE!”-style share button.
- Right side: “LEADERBOARD” with multiple “ADD FRIEND” rows.

### Population/building tutorial, roughly 3:05–4:30

- New/smaller city with homes, civic/commercial structures, roads, trees, a gas station, and a circular building.
- Adviser says more population is needed.
- Building deck shows multiple residential/commercial cards with costs in colored resource boxes.
- A “WHOA THERE!” tutorial explains following blinking arrows and clicking where indicated.
- Objective panel later reads approximately “DESTROY ONE RESIDENTIAL BUILDING.”
- A building tooltip for a unit/card is visible; exact name and stats are too small to transcribe confidently.

### Second attack, roughly 4:30–7:00

- A broad turquoise attack path is highlighted across the city.
- A green monster is visible entering or attacking from the left.
- City structures show damage, fire, warning markers, and destroyed spots.
- The camera remains fixed isometric; no manual camera pan is demonstrated.

### Unit/building catalog, roughly 7:30–9:30

- Player hovers/selects multiple cards in the bottom deck.
- Several cards show colored resource costs, including visible values around 450, 650, and 1100 in one sampled frame; do not treat these as final balance values because the video resolution is low.
- A selected card tooltip has a name that is not legible enough to reproduce accurately.
- The video ends while browsing/using the card deck in the city.

## 8. Recommended recreation data model

Use these entities:

- `City`: map bounds, camera transform, roads, objects, objectives, score multiplier, timer.
- `Building`: type, footprint, position, rotation, population contribution, business contribution, defense contribution, health, state, repair cost, destruction effects.
- `Monster`: type, cost, health, movement speed, attack range, damage, attack interval, target priority, special ability, footprint, animation set.
- `Weapon`: type, cost, targeting mode, radius, damage, friendly-fire rule, cooldown.
- `Resource`: icon, balance, gain sources, spending categories.
- `Mission`: objective type, target filter, allowed units, timer, completion condition, reward bundle, star thresholds.
- `TutorialStep`: adviser text, highlighted entities, arrow path, modal copy, completion trigger.
- `Card`: category, unlock level, cost, stats, icon, selection state.
- `DamageState`: intact, warning, construction, damaged, burning, destroyed, repaired.

## 9. Art and animation asset list

To reproduce the video’s look, prepare:

- Isometric terrain tile/material set: grass, road, sidewalk, dirt, stone wall.
- Residential set: at least three red-roof house variants.
- Civic/commercial set: town hall, multistory block, gas station, shop, circular building.
- Defense set: machine-gun nest, turret, construction scaffold.
- Destruction set: smoke, fire, blackened facade, rubble pile, crater, sparks.
- Vegetation set: conifers, deciduous trees, pink flowering tree.
- Props: vehicles, signs, balloons, street furniture, construction materials.
- Giant Ape model with idle, walk, attack, hit, roar/celebration, death/retreat animations.
- At least one green monster variant and one purple energy/weapon effect.
- Adviser character portrait and speech-bubble illustrations.
- Resource icons, card icons, category icons, warning markers, arrows, route overlays, stars, score/reward icons.
- UI panels matching the orange-header tutorial cards and pale bottom card tray.

## 10. Audio inferred from the presentation

The supplied video does not provide a reliable way to transcribe the original game audio separately. For a faithful first pass, plan for:

- Light casual-game background loop.
- Soft UI click, card-select, construction, repair, and confirmation sounds.
- Monster footsteps and attack impacts.
- Building collapse, fire, explosion, and area-damage sounds.
- Reward/score fanfare and star-rating stingers.
- Optional adviser voice or text-only adviser; the video clearly depends on readable text even if voice audio is absent.

## 11. Accuracy limits and next evidence needed

This single 9:30 video is enough to reproduce the visible core loop and visual language, but not enough to recover exact game content. It does not expose complete unit rosters, exact stats, all building recipes, full progression, sound files, original textures, backend/social behavior, or every screen.

For maximum accuracy before implementation, gather:

- The linked “MonsterMind (Facebook) Gameplay Part 2” video shown beside the source.
- Other archived MonsterMind gameplay videos, especially videos showing the catalog, map progression, and later monsters.
- High-resolution screenshots or archived captures of every tutorial card and tooltip.
- Any surviving fan wiki, screenshots, game files, or browser-game archival material.
- Exact font, icon, and color references from close-up captures.

## 12. Implementation priority

1. Fixed isometric city scene and road-grid navigation.
2. Buildings with intact/damaged/burning/destroyed states.
3. Bottom card deck and resource costs.
4. Giant Ape deployment, route following, target selection, and melee destruction.
5. Objectives, warning markers, adviser/tutorial overlays, and timers.
6. Population/defense balance rules.
7. City-complete score/reward/leaderboard presentation.
8. Additional monsters, bombs, turrets, construction, and social/share features.

The most important fidelity targets are the isometric framing, bright toy-like city art, card-and-resource HUD, adviser/tutorial presentation, turquoise deployment overlays, autonomous monster attacks, and readable destruction feedback.
