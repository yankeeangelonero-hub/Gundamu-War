(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) { module.exports = factory(); }
  else { root.BACKPACK = factory(); }
}(typeof globalThis !== 'undefined' ? globalThis : this, function () {
'use strict';
var ITEMS = [
  {id:'pulse-core',      name:'Pulse Core',       shape:[[0,0],[1,0],[0,1],[1,1]], stats:{hp:20,energy:15,attack:5}},
  {id:'power-conduit',   name:'Power Conduit',    shape:[[0,0],[0,1],[0,2]],       stats:{energy:20,attack:3}},
  {id:'capacitor-cell',  name:'Capacitor Cell',   shape:[[0,0],[0,1]],             stats:{energy:12}},
  {id:'thermal-sink',    name:'Thermal Sink',     shape:[[0,0],[1,0]],             stats:{defense:8,hp:5}},
  {id:'beam-lance',      name:'Beam Lance',       shape:[[0,0],[0,1],[0,2],[0,3]], stats:{attack:25}},
  {id:'razor-saber-pair',name:'Razor Saber Pair', shape:[[0,0],[1,0],[0,1],[1,1]], stats:{attack:20,speed:5}},
  {id:'arc-rifle',       name:'Arc Rifle',        shape:[[0,0],[0,1],[0,2]],       stats:{attack:18,energy:-5}},
  {id:'rail-javelin',    name:'Rail Javelin',     shape:[[0,0],[0,1],[0,2],[0,3]], stats:{attack:30,energy:-10}},
  {id:'missile-hive',    name:'Missile Hive',     shape:[[0,0],[1,0],[0,1],[1,1]], stats:{attack:22,hp:-5}},
  {id:'reactive-plate',  name:'Reactive Plate',   shape:[[0,0],[1,0]],             stats:{defense:15,hp:10}},
  {id:'prism-shield',    name:'Prism Shield',     shape:[[0,0],[1,0],[0,1],[1,1]], stats:{defense:25}},
  {id:'vector-thruster', name:'Vector Thruster',  shape:[[0,0],[0,1]],             stats:{speed:20}},
  {id:'targeting-fin',   name:'Targeting Fin',    shape:[[0,0]],                   stats:{attack:8,speed:5}}
];
var ADJ_RULES = [
  {a:'pulse-core',      b:'power-conduit',  bonus:{energy:10},         label:'Power Loop'},
  {a:'beam-lance',      b:'targeting-fin',  bonus:{attack:12},         label:'Precision Strike'},
  {a:'reactive-plate',  b:'prism-shield',   bonus:{defense:15},        label:'Layered Guard'},
  {a:'vector-thruster', b:'targeting-fin',  bonus:{speed:8,attack:5},  label:'Swift Strike'},
  {a:'missile-hive',    b:'thermal-sink',   bonus:{attack:10},         label:'Hot Launch'},
  {a:'rail-javelin',    b:'power-conduit',  bonus:{attack:15},         label:'Rail Surge'},
  {a:'arc-rifle',       b:'capacitor-cell', bonus:{attack:8,energy:5}, label:'Charge Shot'}
];
var PRESETS = {
  'dawn-knife':{name:'Dawn Knife',placements:[
    {itemId:'vector-thruster', col:0,row:0,rot:0},
    {itemId:'razor-saber-pair',col:1,row:0,rot:0},
    {itemId:'targeting-fin',   col:3,row:0,rot:0},
    {itemId:'power-conduit',   col:4,row:0,rot:0},
    {itemId:'capacitor-cell',  col:5,row:0,rot:0}
  ]},
  'bastion-choir':{name:'Bastion Choir',placements:[
    {itemId:'pulse-core',    col:0,row:0,rot:0},
    {itemId:'prism-shield',  col:2,row:0,rot:0},
    {itemId:'reactive-plate',col:4,row:0,rot:0},
    {itemId:'thermal-sink',  col:4,row:1,rot:0}
  ]},
  'choir-breaker':{name:'Choir Breaker',placements:[
    {itemId:'rail-javelin', col:0,row:0,rot:0},
    {itemId:'power-conduit',col:1,row:0,rot:0},
    {itemId:'beam-lance',   col:2,row:0,rot:0},
    {itemId:'targeting-fin',col:3,row:0,rot:0},
    {itemId:'arc-rifle',    col:3,row:1,rot:0}
  ]},
  'bad-lab-rig':{name:'Bad Lab Rig',placements:[
    {itemId:'missile-hive',   col:0,row:0,rot:0},
    {itemId:'thermal-sink',   col:2,row:0,rot:0},
    {itemId:'arc-rifle',      col:4,row:0,rot:0},
    {itemId:'vector-thruster',col:5,row:0,rot:0},
    {itemId:'capacitor-cell', col:0,row:2,rot:0},
    {itemId:'targeting-fin',  col:1,row:2,rot:0}
  ]}
};
function rotateShape(s){var m=0;for(var i=0;i<s.length;i++)if(s[i][1]>m)m=s[i][1];return s.map(function(p){return[m-p[1],p[0]];});}
function getItem(id){for(var i=0;i<ITEMS.length;i++)if(ITEMS[i].id===id)return ITEMS[i];return null;}
function getOccupiedCells(itemId,col,row,rot){
  var item=getItem(itemId);if(!item)return[];
  var sh=item.shape.map(function(p){return[p[0],p[1]];});
  for(var r=0;r<(rot||0);r++)sh=rotateShape(sh);
  return sh.map(function(p){return[col+p[0],row+p[1]];});
}
function emptyGrid(){var g=[];for(var r=0;r<5;r++){var row=[];for(var c=0;c<6;c++)row.push(null);g.push(row);}return g;}
function canPlace(grid,itemId,col,row,rot){
  var cells=getOccupiedCells(itemId,col,row,rot);if(!cells.length)return false;
  for(var i=0;i<cells.length;i++){var c=cells[i][0],r=cells[i][1];if(c<0||c>=6||r<0||r>=5||grid[r][c]!==null)return false;}
  return true;
}
function placeItem(grid,p){
  if(!canPlace(grid,p.itemId,p.col,p.row,p.rot))return null;
  var cells=getOccupiedCells(p.itemId,p.col,p.row,p.rot);
  var g=grid.map(function(row){return row.slice();});
  var key=p.itemId+'@'+p.col+','+p.row+','+p.rot;
  for(var i=0;i<cells.length;i++)g[cells[i][1]][cells[i][0]]=key;
  return g;
}
function buildGridFromPlacements(placements){
  var g=emptyGrid();
  for(var i=0;i<placements.length;i++){var r=placeItem(g,placements[i]);if(r)g=r;}
  return g;
}
function getActiveAdjacencies(placements){
  var cellMap={},dirs=[[0,1],[0,-1],[1,0],[-1,0]],nbrs={};
  for(var i=0;i<placements.length;i++){
    var p=placements[i],cells=getOccupiedCells(p.itemId,p.col,p.row,p.rot);
    for(var j=0;j<cells.length;j++)cellMap[cells[j][0]+','+cells[j][1]]=p.itemId;
  }
  for(var i=0;i<placements.length;i++){
    var p=placements[i],cells=getOccupiedCells(p.itemId,p.col,p.row,p.rot);
    if(!nbrs[p.itemId])nbrs[p.itemId]={};
    for(var j=0;j<cells.length;j++)for(var d=0;d<dirs.length;d++){
      var nk=(cells[j][0]+dirs[d][0])+','+(cells[j][1]+dirs[d][1]),nid=cellMap[nk];
      if(nid&&nid!==p.itemId)nbrs[p.itemId][nid]=true;
    }
  }
  var active=[];
  for(var k=0;k<ADJ_RULES.length;k++){var r=ADJ_RULES[k];if(nbrs[r.a]&&nbrs[r.a][r.b])active.push(r);}
  return active;
}
function previewAdjacency(placements,itemId,col,row,rot){
  var before=getActiveAdjacencies(placements),after=getActiveAdjacencies(placements.concat([{itemId:itemId,col:col,row:row,rot:rot}]));
  var bl={};for(var i=0;i<before.length;i++)bl[before[i].label]=true;
  return after.filter(function(r){return!bl[r.label];});
}
function calcStats(placements){
  var s={hp:100,attack:10,defense:5,speed:10,energy:0};
  for(var i=0;i<placements.length;i++){var item=getItem(placements[i].itemId);if(!item)continue;for(var k in item.stats)s[k]=(s[k]||0)+item.stats[k];}
  var adj=getActiveAdjacencies(placements);
  for(var i=0;i<adj.length;i++)for(var k in adj[i].bonus)s[k]=(s[k]||0)+adj[i].bonus[k];
  return s;
}
function simulate(buildA,buildB,seed){
  var rng=((seed|0)>>>0)||42;
  function rand(){rng=(Math.imul(rng,1664525)+1013904223)|0;return(rng>>>0)/0x100000000;}
  var sA=calcStats(buildA.placements),sB=calcStats(buildB.placements);
  var hpA=sA.hp,hpB=sB.hp,events=[],tick=0;
  while(hpA>0&&hpB>0&&tick<50){
    tick++;
    var rA=0.85+rand()*0.30,rB=0.85+rand()*0.30;
    var dA=Math.max(1,Math.round(sA.attack*rA)-Math.floor(sB.defense*0.4));
    var dB=Math.max(1,Math.round(sB.attack*rB)-Math.floor(sA.defense*0.4));
    if(sA.speed>=sB.speed){
      hpB=Math.max(0,hpB-dA);events.push({tick:tick,actor:'A',damage:dA,hpA:hpA,hpB:hpB});
      if(hpB<=0)break;
      hpA=Math.max(0,hpA-dB);events.push({tick:tick,actor:'B',damage:dB,hpA:hpA,hpB:hpB});
    }else{
      hpA=Math.max(0,hpA-dB);events.push({tick:tick,actor:'B',damage:dB,hpA:hpA,hpB:hpB});
      if(hpA<=0)break;
      hpB=Math.max(0,hpB-dA);events.push({tick:tick,actor:'A',damage:dA,hpA:hpA,hpB:hpB});
    }
  }
  return{winner:hpA>0&&hpB<=0?'A':hpB>0&&hpA<=0?'B':'draw',ticks:tick,hpA:Math.max(0,hpA),hpB:Math.max(0,hpB),statsA:sA,statsB:sB,events:events,adjA:getActiveAdjacencies(buildA.placements),adjB:getActiveAdjacencies(buildB.placements)};
}
return{ITEMS:ITEMS,ADJ_RULES:ADJ_RULES,PRESETS:PRESETS,rotateShape:rotateShape,emptyGrid:emptyGrid,getOccupiedCells:getOccupiedCells,canPlace:canPlace,placeItem:placeItem,buildGridFromPlacements:buildGridFromPlacements,getActiveAdjacencies:getActiveAdjacencies,previewAdjacency:previewAdjacency,calcStats:calcStats,simulate:simulate};
}));
