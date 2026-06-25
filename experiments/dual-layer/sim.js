/* dual-layer deck-combat — shared deterministic core
 * Browser harness (dual-layer-deck-combat.html) AND headless checks (runmode-check.cjs,
 * bite-check.cjs) load this one file. Pure + seeded (mulberry32). BEH-001 deterministic.
 *
 * Run models:
 *   construction — whole live deck always available, played by priority (no draw). [ADR 2026-06-07]
 *   draw         — per-turn 3-card hand from a seeded shuffle.
 *   hybrid       — always-available core + a small drawn pool.
 *   round        — Slay-the-Spire rhythm: each ROUND a side refills energy + draws a hand and plays
 *                  several cards until energy runs out, then the other side's round. AI-played.
 *
 * "Bite" pass (2026-06-07): energy is scarce (3/round), strikes/nukes cost more, and BLOCK accrues
 * within a round and RESETS at the owner's next round — so a round is a real spend choice
 * (offense vs defense). Construction (one card/turn) cannot bank a round of block, so it now feels
 * different from round.
 */

function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}

/* ===================== DATA ===================== */
const FRAMES={
  light:{id:'light',name:'Skirmish Frame',jp:'軽',hp:90,armor:2,move:20,init:7,wcap:60,pcap:10,w:14,p:3},
  heavy:{id:'heavy',name:'Bulwark Frame',jp:'重',hp:135,armor:9,move:11,init:4,wcap:104,pcap:8,w:30,p:2},
};
const WEAPONS={
  saber:{id:'saber',name:'Beam Saber',jp:'剣',tag:'saber',reach:18,dmg:27,init:1,w:22,p:4},
  rifle:{id:'rifle',name:'Beam Rifle',jp:'銃',tag:'rifle',reach:82,dmg:13,init:0,w:18,p:5},
  twin:{id:'twin',name:'Twin Sabers',jp:'双',tag:'saber',reach:18,dmg:20,init:3,w:30,p:6,twin:true},
};
const SUPPORTS={
  none:{id:'none',name:'— none —',jp:'',tag:null,w:0,p:0},
  shield:{id:'shield',name:'Tower Shield',jp:'盾',tag:'shield',armorBonus:5,w:22,p:1},
  booster:{id:'booster',name:'Booster',jp:'推',tag:'booster',moveBonus:8,w:16,p:4},
};
// cost = energy; block accrues for the round; strikes are blockable.
const CARDS={
  rush:{id:'rush',name:'Saber Rush',jp:'突',cat:'#ff4d3a',need:'saber',cost:2,cd:1,
    desc:'Far → charge in; in reach → heavy strike.', when:(s,f,st)=>true, act:'rush'},
  slash:{id:'slash',name:'Slash',jp:'斬',cat:'#ff4d3a',need:'saber',cost:1,cd:0,
    desc:'In reach → strike.', when:(s,f,st)=>st.dist<=s.reach, act:'strike'},
  burst:{id:'burst',name:'Beam Burst',jp:'爆',cat:'#ff4d3a',need:'saber',cost:3,cd:2,
    desc:'In reach → all-in heavy strike (eats the whole round).', when:(s,f,st)=>st.dist<=s.reach, act:'burst'},
  feint:{id:'feint',name:'Feint',jp:'誘',cat:'#3fd6f0',need:'saber',cost:1,cd:1,
    desc:'In reach → next strike this round crits.', when:(s,f,st)=>st.dist<=s.reach&&!s.combo, act:'feint'},
  snap:{id:'snap',name:'Snap Shot',jp:'射',cat:'#ffb43a',need:'rifle',cost:1,cd:0,
    desc:'Within rifle range → ranged hit.', when:(s,f,st)=>st.dist<=s.reach, act:'shoot'},
  volley:{id:'volley',name:'Beam Volley',jp:'掃',cat:'#ffb43a',need:'rifle',cost:3,cd:2,
    desc:'Within range → heavy ranged barrage.', when:(s,f,st)=>st.dist<=s.reach, act:'burst'},
  keep:{id:'keep',name:'Keep Distance',jp:'離',cat:'#3fd6f0',need:null,cost:1,cd:0,
    desc:'Enemy too close → back off.', when:(s,f,st)=>st.dist<s.reach*0.7, act:'retreat'},
  close:{id:'close',name:'Close In',jp:'接',cat:'#56e08a',need:null,cost:1,cd:0,
    desc:'Enemy out of reach → advance.', when:(s,f,st)=>st.dist>s.reach, act:'close'},
  guard:{id:'guard',name:'Brace',jp:'防',cat:'#6aa3ff',need:null,cost:1,cd:0,
    desc:'Gain 12 block for the round (absorbs damage, resets next round).', when:(s,f,st)=>s.block<24, act:'block', block:12},
  overdrive:{id:'overdrive',name:'Overdrive',jp:'過',cat:'#ffb43a',need:null,cost:2,cd:2,
    desc:'Ahead on HP → double the next strike.', when:(s,f,st)=>s.hp>=f.hp&&!s.od, act:'overdrive'},
  hold:{id:'hold',name:'Hold the Line',jp:'守',cat:'#6aa3ff',need:'shield',cost:2,cd:1,
    desc:'Gain 26 block for the round (shield).', when:(s,f,st)=>s.block<26, act:'block', block:26},
  dash:{id:'dash',name:'Boost Dash',jp:'駆',cat:'#56e08a',need:'booster',cost:2,cd:2,
    desc:'Reposition fast (close the gap hard).', when:(s,f,st)=>st.dist>s.reach, act:'dash'},
};
const POOL_ORDER=['rush','slash','burst','feint','snap','volley','keep','close','guard','overdrive','hold','dash'];
const PRESETS={
  'Berserker':['rush','slash','burst','feint','overdrive','close'],
  'Spacer':['snap','keep','close','guard','overdrive'],
  'Bulwark':['guard','hold','slash','close','feint'],
  'Big Aggro':['rush','close','slash','slash','feint','burst','close','overdrive','slash','keep'],
  'Big Turtle':['close','guard','guard','slash','hold','close','feint','slash','keep','overdrive'],
};
const GHOST={ name:'"KESTREL"', frame:'light', weapon:'rifle', support:'booster',
  deck:['snap','keep','dash','volley','guard'] };

// Rarity = deckbuilding COPY LIMIT (and acquisition flavour), NOT a power tier a newcomer can't
// reach: everyone can run the cap of any card. Cheap/common → more copies; rare/strong → fewer.
const RARITY_MAX={ common:3, uncommon:2, rare:1 };
const CARD_RARITY={ slash:'common', snap:'common', close:'common', keep:'common', guard:'common',
  rush:'uncommon', feint:'uncommon', overdrive:'uncommon', dash:'uncommon',
  burst:'rare', volley:'rare', hold:'rare' };
const RARITY_COLOR={ common:'#8b93a6', uncommon:'#6aa3ff', rare:'#ffb43a' };
function cardRarity(id){return CARD_RARITY[id]||'common';}
function cardMax(id){return RARITY_MAX[cardRarity(id)];}
const DECK_MAX=12;

const ROUND_ENERGY = 3;
const ROUND_HAND   = 5;
const ROUND_MAXPLAYS = 8;

/* ===================== BODY HELPERS ===================== */
function bodyTags(b){return [WEAPONS[b.weapon].tag, SUPPORTS[b.support].tag].filter(Boolean);}
function bodyWeight(b){return FRAMES[b.frame].w+WEAPONS[b.weapon].w+SUPPORTS[b.support].w;}
function bodyPower(b){return FRAMES[b.frame].p+WEAPONS[b.weapon].p+SUPPORTS[b.support].p;}
function overWeight(b){return bodyWeight(b)>FRAMES[b.frame].wcap;}
function overPower(b){return bodyPower(b)>FRAMES[b.frame].pcap;}
function cardDead(cardId,b){const c=CARDS[cardId];return !!c.need && !bodyTags(b).includes(c.need);}

function makeCombatant(b,deck,name,col){
  const fr=FRAMES[b.frame],wp=WEAPONS[b.weapon],sp=SUPPORTS[b.support];
  let move=fr.move+(sp.moveBonus||0); if(overWeight(b))move=Math.round(move*0.6);
  let armor=fr.armor+(sp.armorBonus||0);
  let regen=2; if(overPower(b))regen=1;
  return {
    name,col, hp:fr.hp, maxhp:fr.hp, armor, move, reach:wp.reach, dmg:wp.dmg,
    init:fr.init+wp.init, regen, energy:3, body:b, block:0,
    deck:deck.slice(), cds:{}, combo:false, od:false,
  };
}

/* ===================== SIM ===================== */
function setupCards(c,mode,rng,brokenRng){
  c.live=c.deck.filter(id=>!cardDead(id,c.body));
  c.dead=c.deck.filter(id=>cardDead(id,c.body));
  const shuf=(arr)=>{const r=brokenRng||rng;for(let i=arr.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[arr[i],arr[j]]=[arr[j],arr[i]];}};
  c._shuf=shuf;
  if(mode==='construction'){c.avail=()=>c.live.slice();return;}
  if(mode==='round'){
    let pile=c.live.slice(); shuf(pile);
    c.pile=pile; c.discard=[]; c.hand=[]; c.handSize=ROUND_HAND; c.coreSet=new Set();
    return;
  }
  const core = mode==='hybrid' ? c.live.filter(id=>['guard','close','keep','slash','snap'].includes(id)) : [];
  c.coreSet=new Set(core);
  let pile=c.live.filter(id=>!c.coreSet.has(id));
  shuf(pile);
  c.pile=pile; c.discard=[]; c.hand=[]; c.handSize=3;
  drawUp(c);
  c.avail=()=>[...core,...c.hand];
}
function drawUp(c){
  while(c.hand.length<c.handSize){
    if(!c.pile.length){ if(!c.discard.length)break; c.pile=c.discard; c.discard=[]; c._shuf(c.pile); }
    c.hand.push(c.pile.shift());
  }
}
function priorityIndex(c,id){const i=c.deck.indexOf(id);return i<0?99:i;}

function applyCard(st,s,f,id){
  const c=CARDS[id]; let e={who:s.tag,name:c.name};
  const strike=(mult)=>{
    if(st.dist>s.reach){e.whiff=true;e.txt=`${c.name} — whiffs, ${Math.round(st.dist-s.reach)}m out of reach`;return;}
    let dmg=s.dmg*mult; if(s.combo){dmg*=1.6;s.combo=false;e.crit=true;} if(s.od){dmg*=2;s.od=false;e.od=true;}
    if(WEAPONS[s.body.weapon].twin)dmg*=1.18;
    dmg=Math.max(1,Math.round(dmg-f.armor));
    if(f.block>0){const ab=Math.min(f.block,dmg);f.block-=ab;dmg-=ab;e.blocked=ab;}
    if(dmg>0)f.hp-=dmg; e.dmg=dmg;
    e.txt=`${c.name} — ${e.crit?'CRIT ':''}${e.od?'OVERDRIVE ':''}${dmg>0?('hits for '+dmg):'fully blocked'}${e.blocked?(' ('+e.blocked+' blocked)'):''}`;
  };
  switch(c.act){
    case 'rush': if(st.dist>s.reach){st.dist=Math.max(0,st.dist-s.move*1.5);} if(st.dist<=s.reach){strike(1.1);} else {e.txt=`${c.name} — charges in (${Math.round(st.dist)}m)`;e.move=true;} break;
    case 'dash': st.dist=Math.max(0,st.dist-s.move*1.8); e.txt=`${c.name} — boosts in to ${Math.round(st.dist)}m`; e.move=true; break;
    case 'close': st.dist=Math.max(0,st.dist-s.move); e.txt=`${c.name} — advances to ${Math.round(st.dist)}m`; e.move=true; break;
    case 'retreat': st.dist=Math.min(100,st.dist+s.move); e.txt=`${c.name} — backs off to ${Math.round(st.dist)}m`; e.move=true; break;
    case 'strike': strike(1); break;
    case 'shoot': strike(1); break;
    case 'burst': strike(2.2); break;
    case 'feint': s.combo=true; e.txt=`${c.name} — sets up a crit`; break;
    case 'overdrive': s.od=true; e.txt=`${c.name} — next strike doubled`; break;
    case 'block': s.block+=c.block; e.block=true; e.txt=`${c.name} — block ${s.block}`; break;
  }
  return e;
}

function stamp(ev,st,A,B){ev.dist=Math.round(st.dist);ev.aHp=Math.max(0,A.hp);ev.bHp=Math.max(0,B.hp);ev.aBlk=Math.max(0,A.block);ev.bBlk=Math.max(0,B.block);return ev;}

function simulate(A,B,seed,mode,opts){
  opts=opts||{};
  const rng=mulberry32(seed>>>0);
  const brokenRng=opts.brokenShuffle?Math.random:null;
  const st={dist:64,prevDist:64,turn:0,events:[]};
  A.tag='a';B.tag='b';
  setupCards(A,mode,rng,brokenRng); setupCards(B,mode,rng,brokenRng);
  const fire=A.init>=B.init?[A,B]:[B,A];
  const counts={a:{},b:{}};

  if(mode==='round'){
    let round=0;
    while(A.hp>0&&B.hp>0&&round<60){
      round++;
      for(const s of fire){
        if(A.hp<=0||B.hp<=0)break;
        const f=s===A?B:A;
        s.energy=ROUND_ENERGY; s.block=0; s.combo=false;
        for(const k in s.cds)if(s.cds[k]>0)s.cds[k]--;
        if(s.hand.length){s.discard.push(...s.hand);s.hand=[];} // STS: discard leftover hand, draw fresh (no hand-lock)
        drawUp(s);
        let plays=0, acted=false;
        while(plays<ROUND_MAXPLAYS){
          const cand=s.hand.slice().sort((x,y)=>priorityIndex(s,x)-priorityIndex(s,y));
          let chosen=null;
          for(const id of cand){const c=CARDS[id]; if((s.cds[id]||0)>0)continue; if(s.energy<c.cost)continue; if(!c.when(s,f,st))continue; chosen=id;break;}
          if(!chosen)break;
          const c=CARDS[chosen];
          const r=applyCard(st,s,f,chosen);
          s.energy-=c.cost; s.cds[chosen]=c.cd;
          counts[s.tag][chosen]=(counts[s.tag][chosen]||0)+1;
          const hi=s.hand.indexOf(chosen); if(hi>=0){s.hand.splice(hi,1); s.discard.push(chosen);}
          st.turn++;
          st.events.push(stamp(Object.assign({turn:st.turn,who:s.tag,round},r),st,A,B));
          plays++; acted=true;
          if(A.hp<=0||B.hp<=0)break;
        }
        if(!acted) st.events.push(stamp({turn:++st.turn,who:s.tag,round,sys:true,txt:'holds — no playable card in hand this round'},st,A,B));
        if(A.hp<=0||B.hp<=0)break;
      }
    }
    const winR = A.hp>0 && B.hp<=0 ? 'a' : (B.hp>0&&A.hp<=0?'b':(A.hp>=B.hp?'a':'b'));
    return {events:st.events, win:winR, turns:st.turn, rounds:round, A, B, counts, draw:A.hp>0&&B.hp>0};
  }

  while(A.hp>0&&B.hp>0&&st.turn<80){
    for(const s of fire){
      if(A.hp<=0||B.hp<=0)break;
      const f=s===A?B:A;
      st.turn++;
      s.block=0;
      s.energy=Math.min(6,s.energy+s.regen);
      for(const k in s.cds)if(s.cds[k]>0)s.cds[k]--;
      let chosen=null;
      const cand=s.avail().slice().sort((x,y)=>priorityIndex(s,x)-priorityIndex(s,y));
      for(const id of cand){
        const c=CARDS[id];
        if((s.cds[id]||0)>0)continue;
        if(s.energy<c.cost)continue;
        if(!c.when(s,f,st))continue;
        chosen=id;break;
      }
      let ev={turn:st.turn,who:s.tag};
      if(!chosen){
        ev.sys=true; ev.txt='hesitates — no card fits the moment';
        s.energy=Math.min(6,s.energy+1);
      }else{
        const c=CARDS[chosen];
        const r=applyCard(st,s,f,chosen);
        s.energy-=c.cost; s.cds[chosen]=c.cd;
        counts[s.tag][chosen]=(counts[s.tag][chosen]||0)+1;
        Object.assign(ev,r);
        if(mode!=='construction'&&!s.coreSet.has(chosen)&&s.hand){
          const hi=s.hand.indexOf(chosen); if(hi>=0){s.hand.splice(hi,1);s.discard.push(chosen);drawUp(s);}
        }
      }
      st.events.push(stamp(ev,st,A,B));
      st.prevDist=st.dist;
      if(A.hp<=0||B.hp<=0)break;
    }
  }
  const win = A.hp>0 && B.hp<=0 ? 'a' : (B.hp>0&&A.hp<=0?'b':(A.hp>=B.hp?'a':'b'));
  return {events:st.events, win, turns:st.turn, A, B, counts, draw:A.hp>0&&B.hp>0};
}

const KX_SIM = { mulberry32, FRAMES, WEAPONS, SUPPORTS, CARDS, POOL_ORDER, PRESETS, GHOST,
  ROUND_ENERGY, ROUND_HAND, RARITY_MAX, CARD_RARITY, RARITY_COLOR, DECK_MAX, cardRarity, cardMax,
  bodyTags, bodyWeight, bodyPower, overWeight, overPower, cardDead,
  makeCombatant, setupCards, drawUp, priorityIndex, applyCard, simulate };
if (typeof module !== 'undefined' && module.exports) module.exports = KX_SIM;
if (typeof window !== 'undefined') window.KX_SIM = KX_SIM;
