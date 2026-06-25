'use strict';
const fs = require('fs');
const path = require('path');
const BP = require('./backpack-core.js');

const EV = path.join(__dirname, '..', '..', 'Project Version', 'Version 0.4', 'Slices', 'Unit Tests', 'evidence', 'backpack-comparator');
fs.mkdirSync(EV, {recursive: true});

let pass = 0, fail = 0;
const log = [];
function check(name, cond, info) {
  if (cond) { pass++; log.push('PASS ' + name); }
  else { fail++; log.push('FAIL ' + name + (info ? ' | ' + info : '')); }
}

// AC-1: Grid placement
{
  const g = BP.emptyGrid();
  check('AC-1a emptyGrid 5 rows', g.length === 5);
  check('AC-1b emptyGrid 6 cols', g[0].length === 6);
  let grid = g, allOk = true;
  for (const p of BP.PRESETS['dawn-knife'].placements) {
    if (BP.canPlace(grid, p.itemId, p.col, p.row, p.rot)) {
      grid = BP.placeItem(grid, p);
    } else {
      allOk = false;
      log.push('  placement fail: ' + p.itemId + ' @ ' + p.col + ',' + p.row);
    }
  }
  check('AC-1c dawn-knife all placements succeed', allOk);
  check('AC-1d overlap rejected', !BP.canPlace(grid, 'targeting-fin', 0, 0, 0));
  check('AC-1e OOB col>=6 rejected', !BP.canPlace(BP.emptyGrid(), 'targeting-fin', 6, 0, 0));
  check('AC-1f OOB row>=5 rejected', !BP.canPlace(BP.emptyGrid(), 'targeting-fin', 0, 5, 0));
  const evData = {preset:'dawn-knife',placements:BP.PRESETS['dawn-knife'].placements,allOk,overlapRejected:!BP.canPlace(grid,'targeting-fin',0,0,0),oobRejected:!BP.canPlace(BP.emptyGrid(),'targeting-fin',6,0,0)};
  fs.writeFileSync(path.join(EV, 'placement.json'), JSON.stringify(evData, null, 2));
  log.push('  wrote placement.json');
}

// AC-2: Adjacency preview
{
  const cb = BP.PRESETS['choir-breaker'];
  const adj = BP.getActiveAdjacencies(cb.placements);
  check('AC-2a choir-breaker Rail Surge active', adj.some(r => r.label === 'Rail Surge'));
  check('AC-2b choir-breaker Precision Strike active', adj.some(r => r.label === 'Precision Strike'));
  const withoutBeam = cb.placements.filter(p => p.itemId !== 'beam-lance');
  const g2 = BP.buildGridFromPlacements(withoutBeam);
  const canB = BP.canPlace(g2, 'beam-lance', 2, 0, 0);
  const prev = canB ? BP.previewAdjacency(withoutBeam, 'beam-lance', 2, 0, 0) : [];
  check('AC-2c beam-lance fits at (2,0) in partial build', canB);
  check('AC-2d preview finds Precision Strike', prev.some(r => r.label === 'Precision Strike'), 'prev=' + prev.map(r => r.label).join(','));
  check('AC-2e lone targeting-fin has no active adjacency', BP.getActiveAdjacencies([{itemId:'targeting-fin',col:3,row:0,rot:0}]).length === 0);
  const md = ['# Adjacency Evidence','',
    '## Choir Breaker active: ' + adj.map(r => r.label).join(', '),'',
    '## Preview beam-lance @ (2,0)','canPlace: ' + canB,'new bonuses: ' + prev.map(r => r.label).join(', '),'',
    '## Bastion Choir active: ' + BP.getActiveAdjacencies(BP.PRESETS['bastion-choir'].placements).map(r => r.label).join(', '),'',
    '## Bad Lab Rig active: ' + BP.getActiveAdjacencies(BP.PRESETS['bad-lab-rig'].placements).map(r => r.label).join(', ')
  ].join('\n');
  fs.writeFileSync(path.join(EV, 'adjacency-preview.md'), md);
  log.push('  wrote adjacency-preview.md');
}

// AC-3: Determinism
{
  const bA = BP.PRESETS['dawn-knife'], bB = BP.PRESETS['bastion-choir'];
  const r1 = BP.simulate(bA, bB, 42);
  const r2 = BP.simulate(bA, bB, 42);
  const r3 = BP.simulate(bA, bB, 99);
  const sameHP = r1.hpA === r2.hpA && r1.hpB === r2.hpB && r1.ticks === r2.ticks && r1.winner === r2.winner;
  const sameEv = JSON.stringify(r1.events) === JSON.stringify(r2.events);
  const diffEv = JSON.stringify(r1.events) !== JSON.stringify(r3.events);
  check('AC-3a same seed same hp/ticks/winner', sameHP);
  check('AC-3b same seed byte-equal events', sameEv);
  check('AC-3c different seeds different events', diffEv);
  const dlog = ['# Determinism Log','',
    'seed=42 run1: winner='+r1.winner+' ticks='+r1.ticks+' hpA='+r1.hpA+' hpB='+r1.hpB,
    'seed=42 run2: winner='+r2.winner+' ticks='+r2.ticks+' hpA='+r2.hpA+' hpB='+r2.hpB,
    'byte-equal: '+sameEv,'',
    'seed=99 run3: winner='+r3.winner+' ticks='+r3.ticks+' hpA='+r3.hpA+' hpB='+r3.hpB,
    'differs from 42: '+diffEv
  ].join('\n');
  fs.writeFileSync(path.join(EV, 'determinism-log.md'), dlog);
  fs.writeFileSync(path.join(EV, 'determinism-diff-note.md'), diffEv ? 'seed-42 and seed-99 produce different event sequences (expected -- determinism confirmed)' : 'WARNING: identical events across seeds');
  log.push('  wrote determinism-log.md + diff-note.md');
}

// AC-4: Debrief comparison
{
  const pk = Object.keys(BP.PRESETS);
  const results = {};
  for (let i = 0; i < pk.length; i++) for (let j = i+1; j < pk.length; j++) {
    const ka=pk[i],kb=pk[j];
    const r=BP.simulate(BP.PRESETS[ka],BP.PRESETS[kb],42);
    results[ka+'_vs_'+kb]={winner:r.winner==='A'?BP.PRESETS[ka].name:r.winner==='B'?BP.PRESETS[kb].name:'draw',ticks:r.ticks,hpA:r.hpA,hpB:r.hpB,adjA:r.adjA.map(x=>x.label),adjB:r.adjB.map(x=>x.label)};
  }
  check('AC-4 all 6 matchups produce results', Object.keys(results).length === 6);
  const lines=['# Debrief Comparison','','| Matchup | Winner | Ticks | HP-A | HP-B |','|---|---|---|---|---|'];
  for (const k in results){const r=results[k];lines.push('| '+k.replace('_vs_',' vs ')+' | '+r.winner+' | '+r.ticks+' | '+r.hpA+' | '+r.hpB+' |');}
  lines.push('','## Adjacency bonuses per fight');
  for (const k in results){const r=results[k];lines.push('- **'+k.replace('_vs_',' vs ')+'**: A=['+r.adjA.join('+')+'] B=['+r.adjB.join('+')+']');}
  fs.writeFileSync(path.join(EV, 'debrief-comparison.md'), lines.join('\n'));
  const sumLines=['# Comparison Summary',''];
  for (const k in results){const r=results[k];sumLines.push('- **'+k.replace('_vs_',' vs ')+'**: '+r.winner+' wins in '+r.ticks+' ticks');}
  fs.writeFileSync(path.join(EV, 'comparison.md'), sumLines.join('\n'));
  log.push('  wrote debrief-comparison.md + comparison.md');
}

// AC-5: Preset coverage
{
  const pks = Object.keys(BP.PRESETS);
  check('AC-5a 4 presets defined', pks.length === 4);
  let allValid = true;
  for (const k of pks) {
    let g = BP.emptyGrid();
    for (const p of BP.PRESETS[k].placements) {
      if (!BP.canPlace(g, p.itemId, p.col, p.row, p.rot)) {
        allValid = false;
        log.push('  invalid: ' + k + ' ' + p.itemId + ' @' + p.col + ',' + p.row);
        break;
      }
      g = BP.placeItem(g, p);
    }
  }
  check('AC-5b all preset placements non-overlapping', allValid);
}

// Report
console.log('\n=== Backpack Comparator Check ===');
log.forEach(l => console.log(l));
console.log('\nPASS: ' + pass + '  FAIL: ' + fail);
if (fail > 0) process.exit(1);
