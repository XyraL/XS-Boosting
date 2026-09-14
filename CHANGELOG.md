# Changelog

## 0.5.7

Everything read flat, so this raises the amplitude rather than redrawing
anything. Same layout, same interface, more of it.

- **A tier looks like itself everywhere.** The board already tinted its cards;
  now each one carries its tier along the top edge and in the payout figure,
  and the same colours run through the rep ladder and the fence rates. Four
  identical blue bars became four tiers you can pick out without reading.
- **Real elevation.** Every shadow is now two — a tight contact shadow that
  sits a surface on what is behind it, and a wide soft one that lifts it off —
  and raised edges get a highlight on top with shade underneath. A single blur
  reads as a sticker.
- **Grain over the whole interface.** Large flat fills of near-black look like
  painted plastic. A little noise gives them a surface.
- **Stat cards look built rather than typed.** Big gradient figure, light
  falling across the corner, a stub of accent underneath.
- **The accent actually appears.** Window rim, sidebar selection, tile icons,
  primary buttons and panel titles all carry it now, instead of one blue word
  per screen.
- Slabs, feed rows and tables sit on the page instead of in it, and a table row
  marks itself under the cursor.
- **Custom profile pictures are on by default.** Players can point their
  picture at an image of their own instead of only taking one of the twelve
  the unit draws. Links must be http(s), carry no username or port, and fall
  back to the player's initials if they fail to load. `Config.Profile` still
  restricts them to hosts you trust, or switches them off — worth doing on a
  public server, since whatever somebody pastes is shown to everybody who
  opens a leaderboard.

## 0.5.6

- **You could drive off without hotwiring.** Nothing was actually holding the
  car. `SetVehicleNeedsToBeHotwired` only delays GTA's own start by a few
  seconds before the engine catches by itself, and a keys resource will hand an
  unowned car to whoever sits in it — so sitting still for a moment was enough,
  and the whole hotwire stage was decoration. The engine is now held off and
  the throttle dead, every frame, until the hotwire lands. Keys are still
  granted on success and never before.
- **The handed-over car now leaves with the buyer.** The buyer walked off the
  instant the job ended and the car sat there for another six seconds with
  nobody next to it, which read as the handover not having worked. One second
  now — long enough to put anybody still sat in it out first, so the car is not
  deleted from under them.

## 0.5.5

- **Everything placed came back switched off after a restart.** A `TINYINT(1)`
  does not come back the same way everywhere — oxmysql hands it over as a
  boolean on most builds and a number on others — so reading it as `== 1` was a
  coin toss, and when it lost every spawn point, handover and chop shop loaded
  disabled. Any of the three forms counts now. `/boostplaces` says what is
  placed and how much of it is on; `/boostplaces on` switches the rest back on,
  for anything that was saved while it read as off.
- **You can crew up before anybody takes anything.** The crew panel no longer
  needs a job running. Put people on the list while you are stood around, and
  the moment one of you takes a contract the rest are pulled straight into it,
  told what they have just joined — no second round of invites while the clock
  runs. The crew survives the job, so the next one needs no setting up. Up to
  four, and it feeds the heist as well. One button still covers both: with a
  contract running it puts somebody into that, on foot it builds the crew.
  See `Config.Crew`.
- **Every player sees a different board.** Boards are per player now, so two
  people opening a unit at the same moment are not looking at the same six cars
  and nobody is racing anybody for a listing. The contested server event is the
  deliberate exception and stays shared. `Config.Contracts.sharedBoard` puts
  everybody back on one board.
- A spawn point now rests when the contract is *taken* rather than when it is
  listed. Six listings a player, and the old timing would have retired every
  spawn on the map before anybody drove anywhere. Two boards that happen to
  point at the same corner are separated when the second one is accepted.
- Bringing somebody into a running heist pushed them the wrong state shape,
  which stripped the cars and the exit out of their page.
- The admin board button rerolls every board rather than topping them up, which
  is what it reads as.

## 0.5.4

Second in-game pass.

- **Job alerts crashed the police dispatch bridge.** The HUD's job alerts had
  been registered on the same event name as the police-facing dispatch alert,
  so a crew member who happened to be on a police job got a dispatch handler
  reading a HUD payload. Two handlers, two payload shapes, one name. The HUD's
  is now `XS-Boosting:client:jobAlert`, and the dispatch one ignores anything
  with no coordinates on it.
- **Target cars flipped on approach.** Spawn points are saved at road height,
  but a vehicle's origin is the middle of its chassis — so the car was created
  inside the road and thrown out. They are dropped in from just above now and
  settle flat.
- **Hotwiring is a sequence, done from the seat.** Get in, press E, and work
  through three rounds; every one has to land. Succeed and the keys are yours.
  It is no longer something you do stood at the window in one lucky press.
- **The handover is a person.** A buyer turns up at the drop point while the
  job is running and you hand the car to them, rather than standing in a circle.
- **Handed-over cars leave.** They went after a minute before, which meant the
  car was still sat at the drop long after the job ended.
- Places a character had already found were saved but never loaded, so blips
  earned in an earlier session stayed hidden until they were walked past again.
- `tools/check-events.mjs` checks net event wiring — one handler per name,
  nothing sent into the void, nothing listening for something never sent.

## 0.5.3

- **The README's ox_inventory block was missing `client.export`**, so anyone
  copying it got a dead unit — the exact failure 0.5.2 was meant to stop. It was
  also contradicting a note further up the same page. One block now, correct,
  with both lines that matter called out: `client.export` makes the item open
  anything, `consume = 0` stops it being eaten on first use.
- The shipped `items/ox_inventory.lua` had the opposite half of the bug: it had
  the export but no `consume = 0`, so the unit vanished after one use.
- `tools/check-items.mjs` now checks the README and the item files against each
  other and against config, so the two cannot drift apart again.

## 0.5.2

- **The unit did nothing on ox_inventory.** ox_inventory ignores the framework's
  useable-item system, so `CreateUseableItem` was registering against nothing.
  There is now an `XS-Boosting.openUnit` export for its `items.lua` to point at,
  a `useUnit` server export for the other form, and ready-to-paste item
  definitions in `items/`. The server says which inventory it found at start.
- `/boostopen` opens the interface without the item, for admins testing.
- **Far more cars out of the box** — 54 across the four tiers, up from 16.
- The spawn-point car picker now lists **every vehicle the framework knows
  about** underneath the tier's own, so you can check whether a big one fits.

## 0.5.1

Fixes from the first in-game pass.

- **Coordinates reached the interface as null.** A Lua vector3 does not survive
  json into the NUI page, so the builder's Places list threw as soon as it tried
  to read one. Everything crossing that boundary is now flattened first. The
  browser mock had been sending plain objects, which is why it never showed up.
- **The preview car sat in the road.** A vehicle's origin is the middle of its
  chassis, so putting that on the ground buried half of it. The ghost is lifted
  by the model's own height now, and real spawns settle themselves on the road
  whatever Z the point was saved at.
- **Spawn points get a car picker.** Placing one now offers the actual vehicles
  configured for that tier instead of guessing a model, and the list follows the
  tier when you change it.
- **/boostunit** hands an admin a unit, or sends one to a player id — there is
  no way to open the interface without the item, by design.
- The server now says at start if the unit or any tool item is missing from your
  inventory resource, or if nothing has been placed yet. Both failures were
  silent before.

## 0.5.0

- Readme now has the items ready to paste, one block for ox_inventory and one
  for QBCore, instead of just naming them
- **Spawn points rest between jobs.** A spot that has just been used sits out,
  so the board stops serving the same corner and nobody can park next to one
  and farm it. Falls back to a used spot rather than leaving the board short.
- **Admin coverage for the newer systems.** The builder gains a *Contested* tab
  (status, who is in, start, call off, and why one cannot start) and a
  *Lockups* tab listing every parked car with a release action. Spawn rows in
  *Places* now show how long each one is resting for.
- Chop contracts no longer pay twice. Pulling a part gives you the item;
  handing the job in takes the items back and pays for the ones you still have.
  Walking away keeps the parts but not the money.
- Contested wins now read as "Won it" on the record instead of a raw outcome.

## 0.4.0

- **Sound.** Cues across the whole job — stages, alarms, trackers, the clock
  running down, getting paid, losing it, earning an unlock. All GTA's own
  sounds, so nothing to stream. Per-cue config and a player mute switch.
- **Driving targets.** A share of contracts have somebody at the wheel and are
  moving around the city. Stop the car and the driver gets out and runs. No
  alarm, no lock, but the engine dies with them. Per-tier chance.
- **Lockups.** Park a car mid-contract and the clock stops; come back later and
  carry on with the same time on it. Or pay to clean the VIN and keep it in your
  own garage, for no payout and a rep hit.
- **Contested contracts.** One car, everybody at once, armed guards on it, first
  one to the drop keeps it. Announced to everyone holding a unit. On a timer, or
  called by an admin with `/boostevent`.
- Duo remote tracker now works for anyone on the crew who is not the one
  driving, rather than only for the person who is not holding the contract.

## 0.3.0

- New look: black, blue and grey. Layered surfaces, real elevation, rounded
  corners, sans for reading and mono for anything you compare. Cards carry a
  tier-tinted wash, lift on hover and light their action.
- **HUD.** A panel at the edge of the screen while a contract runs, showing the
  plate, the car, the stage, condition and what is fitted to it. Job alerts —
  alarms, trackers going live, police being called — stack underneath and fade
  themselves out. Never takes focus.
- **Settings.** Accent colour, HUD on/off and which side, job alerts, framework
  notifications, in-app messages, start-up animation. Per character, saved on
  the server, validated against a config allowlist.
- Six accent colours: blue, ice, violet, emerald, amber, crimson.
- Panel entrance flow that fires on a real tab change and never on a live
  redraw underneath you.

## 0.2.0

- Rebuilt interface: sidebar with sections, an overview page, cards, a status
  line, and a signed-in block.
- **Profiles.** A handle, a picture and a line under your name. Twelve avatars
  are drawn by the unit itself; custom image links are off by default and can be
  restricted to hosts you trust.
- Leaderboard rows carry faces.

## 0.1.0

First build.

- Contract board with four tiers, three contract types (standard, spec order,
  chop list) and a rep ladder that unlocks them in order
- Search zones rather than waypoints — the zone is offset from the car, so the
  middle of the circle is never where it is parked
- Full theft chain: lock, alarm, immobilizer, tracker, each independently
  switchable and configurable
- ECU handshake for killing trackers, at the car or at a dead zone
- Condition tracked from the moment you touch the car to the moment you sell it,
  with an interpolated payout curve
- Three disposal routes: the buyer, a chop shop, a street fence
- Part stripping with per-part items and a cosmetic teardown
- Duo work, including running the tracker remotely while somebody else drives
- Four-man heist: several cars out of one showroom, one window, one exit
- Live fence market that drifts per tier, with contracts locked to their listed
  rate
- Unlocks: permanent passive buffs earned from what you have actually done
- Handles, so no character names appear on the leaderboard
- Police alerts through any of seven dispatch resources, plus a live moving
  tracker blip drawn by this resource
- In-game builder for every spawn point, handover point, chop shop, fence, dead
  zone and heist site — the resource ships empty
- Admin tools: live job list, force-stop, board rebuild, market shift, rep edit
- Target-driven interaction throughout, with a marker and key fallback for
  servers running no target resource
- Item-gated: no player commands at all
