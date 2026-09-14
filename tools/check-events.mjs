/* Net event wiring.
 *
 * The bug this exists for: two features registered handlers on the same event
 * name with incompatible payloads, so one crashed on the other's messages.
 * Nothing caught it — both names resolved, and every triggered event did have
 * a handler. There were just two of them.
 *
 * lib.callback names are deliberately ignored: those are request/response and
 * are matched up by the library, not by us.
 *
 *   node tools/check-events.mjs
 */

import { readFileSync, readdirSync } from 'node:fs'
import { join, sep } from 'node:path'

const norm = (p) => p.split(sep).join('/')

const walk = (d) => readdirSync(d, { withFileTypes: true }).flatMap((e) =>
  e.isDirectory() ? walk(join(d, e.name)) : [norm(join(d, e.name))])

const lua = (dir) => walk(dir).filter((p) => p.endsWith('.lua'))
const read = (p) => ({ path: p, text: readFileSync(p, 'utf8') })

const files = [...lua('client'), ...lua('server'), ...lua('bridge')].map(read)

const HANDLER = /RegisterNetEvent\(\s*'(XS-Boosting:[^']+)'/g
const CALLBACK = /lib\.callback[.\w]*\(\s*'(XS-Boosting:[^']+)'/g
const NAME = /'(XS-Boosting:[^']+)'/g

let problems = 0

/* Anything the callback library owns is not a net event. */
const callbackNames = new Set()

for (const file of files) {
  for (const m of file.text.matchAll(CALLBACK)) callbackNames.add(m[1])
}

/* Where is each event handled? */
const handlers = new Map()

for (const file of files) {
  for (const m of file.text.matchAll(HANDLER)) {
    if (!handlers.has(m[1])) handlers.set(m[1], new Set())
    handlers.get(m[1]).add(file.path)
  }
}

console.log('--- one event, two meanings ---')
let collisions = 0

for (const [name, where] of handlers) {
  if (where.size > 1) {
    console.log(`  ${name}`)
    for (const f of where) console.log(`      handled in ${f}`)
    collisions++
    problems++
  }
}

if (!collisions) console.log('  none')

/* Every mention that is not its own RegisterNetEvent counts as a send. Names
   travel through helpers — Jobs.Broadcast(job, 'name', ...) — and some are
   raised locally, so matching the trigger call alone reports false positives. */
const mentions = new Map()

for (const file of files) {
  const rest = file.text.replace(HANDLER, '')

  for (const m of rest.matchAll(NAME)) {
    if (callbackNames.has(m[1])) continue
    if (!mentions.has(m[1])) mentions.set(m[1], new Set())
    mentions.get(m[1]).add(file.path)
  }
}

console.log('\n--- sent with nobody listening ---')
let orphans = 0

for (const [name, where] of mentions) {
  if (!handlers.has(name)) {
    console.log(`  ${name} — sent from ${[...where].join(', ')}`)
    orphans++
    problems++
  }
}

if (!orphans) console.log('  none')

console.log('\n--- handled but never sent ---')
let unused = 0

for (const [name, where] of handlers) {
  if (!mentions.has(name)) {
    console.log(`  ${name} — handled in ${[...where].join(', ')}`)
    unused++
    problems++
  }
}

if (!unused) console.log('  none')

console.log(problems ? `\n${problems} problem(s)` : '\nevent wiring is clean')
process.exit(problems ? 1 : 0)
