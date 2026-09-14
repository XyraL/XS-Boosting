/* The README prints the item blocks and items/ ships them. They must agree,
   or somebody copies the wrong one and the unit is dead again. */

import { readFileSync } from 'node:fs'

const readme = readFileSync('README.md', 'utf8')
const ox = readFileSync('items/ox_inventory.lua', 'utf8')
const qb = readFileSync('items/qb_core.lua', 'utf8')

const blocks = [...readme.matchAll(/```lua\n([\s\S]*?)```/g)].map((m) => m[1])

const strip = (s) => s
  .split('\n')
  .filter((l) => !l.trim().startsWith('--') && l.trim() !== '')
  .map((l) => l.trim().replace(/\s+/g, ' '))
  .join('\n')

let problems = 0

// Every item name mentioned in config must appear in both files.
const config = readFileSync('config.lua', 'utf8')
const names = new Set()
for (const m of config.matchAll(/item\s*=\s*'([a-z_]+)'/g)) names.add(m[1])
names.add('boosting_unit')

console.log('items referenced by config:', [...names].join(', '))

for (const name of names) {
  if (name === 'marked_bills') continue
  if (!ox.includes(`['${name}']`)) { console.log(`  MISSING from items/ox_inventory.lua: ${name}`); problems++ }
  if (!qb.includes(`['${name}']`)) { console.log(`  MISSING from items/qb_core.lua: ${name}`); problems++ }
}

// The export is the line that actually matters.
console.log('\nthe line that makes the unit work:')
const oxHasExport = ox.includes("export = 'XS-Boosting.openUnit'")
const readmeHasExport = readme.includes("export = 'XS-Boosting.openUnit'")
const qbUseable = /\['boosting_unit'\][^\n]*useable = true/.test(qb)
const readmeQbUseable = /\['boosting_unit'\][^\n]*useable = true/.test(readme)

console.log(`  items/ox_inventory.lua client.export : ${oxHasExport ? 'yes' : 'NO'}`)
console.log(`  README ox_inventory block export     : ${readmeHasExport ? 'yes' : 'NO'}`)
console.log(`  items/qb_core.lua useable=true       : ${qbUseable ? 'yes' : 'NO'}`)
console.log(`  README qb block useable=true         : ${readmeQbUseable ? 'yes' : 'NO'}`)

if (!oxHasExport || !readmeHasExport || !qbUseable || !readmeQbUseable) problems++

// consume = 0 on the three tools, or they get eaten.
console.log('\nconsume = 0 (or ox_inventory eats them):')
for (const name of ['boosting_unit', 'boosting_laptop', 'boosting_toolkit']) {
  const block = ox.split(`['${name}']`)[1]?.split('},')[0] || ''
  const ok = block.includes('consume = 0')
  console.log(`  ${name.padEnd(18)} : ${ok ? 'yes' : 'NO'}`)
  if (!ok) problems++
}

// Does the README's ox block match the shipped file?
const oxBlock = blocks.find((b) => b.includes('client = {') || b.includes("export = 'XS-Boosting.openUnit'"))
if (oxBlock) {
  const a = strip(oxBlock)
  const b = strip(ox)
  console.log(`\nREADME ox block matches items/ox_inventory.lua: ${a === b ? 'yes' : 'NO — they have drifted'}`)
  if (a !== b) {
    problems++
    const al = a.split('\n'), bl = b.split('\n')
    for (let i = 0; i < Math.max(al.length, bl.length); i++) {
      if (al[i] !== bl[i]) { console.log(`  first difference at line ${i + 1}:\n    README: ${al[i]}\n    file:   ${bl[i]}`); break }
    }
  }
} else {
  console.log('\nREADME has no ox_inventory block with the export in it')
  problems++
}

console.log(problems ? `\n${problems} problem(s)` : '\nitem docs agree')
process.exit(problems ? 1 : 0)
