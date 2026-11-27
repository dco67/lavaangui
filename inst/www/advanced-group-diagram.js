/* Read-only SVG viewer for lavaangui's experimental multigroup results.
 * No network access, refitting, eval, dependency or main editor modification.
 * The Shiny output supplies only group labels, nodes and estimated parameters.
 */
(() => {
  'use strict';
  if (window.__lvgGroupDiagramLoaded) return;
  window.__lvgGroupDiagramLoaded = true;
  const NS = 'http://www.w3.org/2000/svg';
  const memo = new Map();
  const colors = { loading:'#17658c', regression:'#233d59', covariance:'#21745d', variance:'#627386' };
  function el(tag, attrs={}, text) {
    const e=document.createElement(tag);
    Object.entries(attrs).forEach(([k,v])=>e.setAttribute(k,String(v)));
    if(text!==undefined)e.textContent=String(text);
    return e;
  }
  function svg(tag,attrs={},text) {
    const e=document.createElementNS(NS,tag);
    Object.entries(attrs).forEach(([k,v])=>e.setAttribute(k,String(v)));
    if(text!==undefined)e.textContent=String(text);
    return e;
  }
  function button(label,cb) { const b=el('button',{type:'button',class:'btn btn-default'},label);b.addEventListener('click',cb);return b; }
  function field(label,control) { const l=el('label',{class:'lvg-gd-field'});control.setAttribute('aria-label',label);l.append(el('span',{},label),control);return l; }
  function select(options,value,cb) {
    const s=el('select',{class:'form-control'});
    options.forEach(([v,t])=>s.append(el('option',{value:v},t)));
    s.value=String(value);s.addEventListener('change',()=>cb(s.value));return s;
  }
  function check(label,value,cb) {
    const c=el('input',{type:'checkbox','aria-label':label});c.checked=value;c.addEventListener('change',()=>cb(c.checked));
    const l=el('label',{class:'lvg-gd-check'});l.append(c,document.createTextNode(' '+label));return l;
  }
  const sub=(a,b)=>({x:a.x-b.x,y:a.y-b.y});
  const add=(a,b)=>({x:a.x+b.x,y:a.y+b.y});
  const mul=(a,k)=>({x:a.x*k,y:a.y*k});
  const unit=a=>{const n=Math.hypot(a.x,a.y)||1;return {x:a.x/n,y:a.y/n};};
  const norm=a=>({x:-a.y,y:a.x});
  const mid=(a,b)=>mul(add(a,b),.5);
  const str=a=>`${a.x.toFixed(2)} ${a.y.toFixed(2)}`;
  const clip=(node,direction,gap=5)=>{
    const u=unit(direction), rx=node.w/2, ry=node.h/2;
    const r=node.latent ? 1/Math.sqrt((u.x/rx)**2+(u.y/ry)**2) : Math.min(rx/Math.max(Math.abs(u.x),1e-9),ry/Math.max(Math.abs(u.y),1e-9));
    return add(node,mul(u,r+gap));
  };
  function triangle(tip,outward) {
    const u=unit(outward), base=add(tip,mul(u,12)),side=mul(norm(u),5.8);
    return {base,points:[tip,add(base,side),sub(base,side)]};
  }
  function endpoint(node,toward,arrow) {
    const d=sub(toward,node),tip=clip(node,d,arrow?6:4);
    return arrow?triangle(tip,d):{base:tip,points:null};
  }
  function inside(node,p,pad=0) {
    const rx=node.w/2+pad,ry=node.h/2+pad,dx=p.x-node.x,dy=p.y-node.y;
    return node.latent?(dx/rx)**2+(dy/ry)**2<=1:Math.abs(dx)<=rx&&Math.abs(dy)<=ry;
  }
  function clearHeads(heads,nodes) {
    return heads.every(h=>!nodes.some(n=>[...h,mid(h[0],h[1]),mid(h[0],h[2]),mid(h[1],h[2]),mul(add(add(h[0],h[1]),h[2]),1/3)].some(p=>inside(n,p,1))));
  }
  function geometry(a,b,edge,edgeList,layout,nodes) {
    if(a.id===b.id) {
      // Two visible arrowheads just outside the top boundary.
      const c1={x:a.x-a.w*.62-26,y:a.y-76},c2={x:a.x+a.w*.62+26,y:a.y-76};
      const s=endpoint(a,c1,true),t=endpoint(a,c2,true);
      const heads=[s.points,t.points];
      if(!clearHeads(heads,nodes))return null;
      return {d:`M${str(s.base)} C${str(c1)} ${str(c2)} ${str(t.base)}`,heads,label:{x:a.x,y:a.y-72}};
    }
    const d=sub(b,a), length=Math.hypot(d.x,d.y), u=unit(d), n=norm(u);
    // When users drag centers onto each other, don't invent a direction.
    if(length<2||inside(a,b,10)||inside(b,a,10))return null;
    let control=mid(a,b), bend=0;
    if(edge.op==='~~') {
      // Put latent covariances to the left and observed residual covariances
      // to the right in a measurement layout. Else use an outward arc.
      const other=edgeList.filter(x=>x.op==='~~'&&x.from!==x.to);
      const rank=Math.max(0,other.findIndex(x=>x.key===edge.key));
      const arc=Math.min(140,54+length*.12+rank%3*17);
      if(layout==='measurement'&&Math.abs(d.y)>Math.abs(d.x)*1.5) {
        control.x+=(a.latent&&b.latent?-1:1)*arc;
      } else if(Math.abs(d.y)<Math.abs(d.x)*.55) control.y-=arc;
      else control=add(control,mul(n,arc));
    } else {
      const reverse=edgeList.some(e=>e.op!=='~~'&&e.from===edge.to&&e.to===edge.from);
      const samePair=edgeList.filter(e=>e.op!=='~~'&&e.from===edge.from&&e.to===edge.to);
      if(reverse) bend=38;
      if(samePair.length>1) bend+=(samePair.findIndex(e=>e.key===edge.key)-(samePair.length-1)/2)*42;
      control=add(control,mul(n,bend));
    }
    // Route a long edge around intervening nodes when possible. Preserve the
    // direction of the preferred covariance/reciprocal bend before trying alternatives.
    const others=nodes.filter(node=>node.id!==a.id&&node.id!==b.id);
    const preferred=sub(control,mid(a,b));
    const direction=Math.hypot(preferred.x,preferred.y)>1?unit(preferred):n;
    const candidates=[control,...[80,140,200,280,360].flatMap(offset=>[add(control,mul(direction,offset)),add(mid(a,b),mul(direction,-offset))])];
    let fallback=null;
    for(const c of candidates) {
      const s=endpoint(a,c,edge.op==='~~'),t=endpoint(b,c,true);
      const heads=[s.points,t.points].filter(Boolean);
      if(Math.hypot(t.base.x-s.base.x,t.base.y-s.base.y)<8||!clearHeads(heads,nodes))continue;
      // Avoid arrows pointing backwards when boxes have been dragged together.
      if((t.base.x-s.base.x)*u.x+(t.base.y-s.base.y)*u.y<4)continue;
      const curve=edge.op==='~~'||Math.hypot(c.x-mid(a,b).x,c.y-mid(a,b).y)>.1;
      const at=v=>curve?add(add(mul(s.base,(1-v)**2),mul(c,2*v*(1-v))),mul(t.base,v*v)):add(mul(s.base,1-v),mul(t.base,v));
      let label=at(.5);
      const labelNormal=norm(unit(sub(t.base,s.base)));
      if(curve)label=add(label,mul(unit(sub(c,mid(a,b))),edge.op==='~~'?32:22));
      else label=add(label,mul(labelNormal,labelNormal.y>0?-15:15));
      const geo={d:curve?`M${str(s.base)} Q${str(c)} ${str(t.base)}`:`M${str(s.base)} L${str(t.base)}`,heads,label};
      if(!fallback)fallback=geo;
      let hit=false;
      for(let i=1;i<40;i++)if(others.some(node=>inside(node,at(i/40),9))){hit=true;break;}
      if(!hit&&!others.some(node=>inside(node,label,15)))return geo;
    }
    // Do not hide a meaningful coefficient merely because a dense diagram
    // has a crossing; its tips are still clear. Users can rearrange nodes.
    return fallback;
  }
  function buildLayout(nodes,edges,kind) {
    const maxW=Math.max(...nodes.map(n=>n.w),112), pad=180;
    const pos={};let width,height;
    if(kind==='measurement') {
      let y=120;
      const factors=nodes.filter(n=>n.latent);
      for(const f of factors) {
        const kids=edges.filter(e=>e.op==='=~'&&e.from===f.id).map(e=>nodes.find(n=>n.id===e.to));
        const start=y,step=95;
        kids.forEach((n,i)=>pos[n.id]={x:pad+maxW+185,y:start+i*step});
        pos[f.id]={x:pad,y:start+(Math.max(1,kids.length)-1)*step/2};
        y+=Math.max(1,kids.length)*step+60;
      }
      width=pad*2+maxW+185;height=Math.max(360,y-80);
    } else {
      const directed=edges.filter(e=>e.op!=='~~'&&e.from!==e.to);
      const degrees=new Map(nodes.map(n=>[n.id,0])),level=new Map(nodes.map(n=>[n.id,0]));
      directed.forEach(e=>degrees.set(e.to,degrees.get(e.to)+1));
      const queue=nodes.filter(n=>degrees.get(n.id)===0).map(n=>n.id);let seen=0;
      for(let i=0;i<queue.length;i++) {
        const id=queue[i];seen++;
        for(const e of directed.filter(e=>e.from===id)) {
          level.set(e.to,Math.max(level.get(e.to),level.get(id)+1));
          degrees.set(e.to,degrees.get(e.to)-1);if(degrees.get(e.to)===0)queue.push(e.to);
        }
      }
      const layers=[];
      if(seen!==nodes.length) {
        const cols=Math.ceil(Math.sqrt(nodes.length));
        nodes.forEach((n,i)=>(layers[Math.floor(i/cols)]??=[]).push(n.id));
      } else nodes.forEach(n=>(layers[level.get(n.id)]??=[]).push(n.id));
      const stepX=maxW+100,stepY=145,maxLayer=Math.max(...layers.map(l=>l.length));
      const horizontal=kind==='horizontal';
      width=pad*2+stepX*Math.max(0,(horizontal?layers.length:maxLayer)-1);
      height=pad*2+stepY*Math.max(0,(horizontal?maxLayer:layers.length)-1);
      layers.forEach((l,i)=>l.forEach((id,j)=>{
        pos[id]=horizontal?{x:pad+i*stepX,y:height/2+(j-(l.length-1)/2)*stepY}:{x:width/2+(j-(l.length-1)/2)*stepX,y:pad+i*stepY};
      }));
    }
    return {pos,width,height};
  }
  function cleanName(s) {return String(s).replace(/[^a-zA-Z0-9_-]+/g,'_').replace(/^_+|_+$/g,'').slice(0,80)||'group';}
  function init(root) {
    if(root.dataset.ready)return;
    root.dataset.ready='1';
    try {
      const p=JSON.parse(root.dataset.payload);
      if(!Array.isArray(p.nodes)||!p.nodes.length||!Array.isArray(p.groups)||p.groups.length<2||!Array.isArray(p.rows))throw Error('Invalid diagram data.');
      const nodes=p.nodes.map(n=>({id:Number(n.id),label:String(n.label),latent:!!n.latent,w:Math.max(112,[...String(n.label)].length*10+30),h:56}));
      const groups=p.groups.map(g=>({id:Number(g.id),label:String(g.label),n:g.n}));
      const nodeMap=new Map(nodes.map(n=>[n.id,n]));
      const edgeMap=new Map();
      const rowMap=new Map();
      for(const row of p.rows) {
        const from=Number(row.from),to=Number(row.to),group=Number(row.group),op=row.op;
        if(!nodeMap.has(from)||!nodeMap.has(to)||!groups.some(g=>g.id===group)||!['=~','~','~~'].includes(op))throw Error('Unrecognized diagram parameter.');
        const key=`${from}:${op}:${to}`;
        if(rowMap.has(`${key}:${group}`))throw Error('Duplicate diagram parameter.');
        edgeMap.set(key,{key,from,to,op});rowMap.set(`${key}:${group}`,row);
      }
      const edges=[...edgeMap.values()];
      const measurement=nodes.some(n=>n.latent)&&edges.every(e=>e.op!=='~')&&nodes.every(n=>n.latent?edges.some(e=>e.op==='=~'&&e.from===n.id):edges.filter(e=>e.op==='=~'&&e.to===n.id).length===1)&&edges.filter(e=>e.op==='=~').every(e=>nodeMap.get(e.from).latent&&!nodeMap.get(e.to).latent);
      const signature=JSON.stringify([nodes.map(n=>[n.id,n.label,n.latent]),edges.map(e=>e.key).sort(),groups.map(g=>[g.id,g.label])]);
      const host=(root.closest('.shiny-bound-output')||root.parentElement)?.id||'lvg-group-diagram';
      const memoKey=host+':'+String(p.viewToken??'standalone')+':'+signature;
      const old=memo.get(memoKey);
      const state=old&&old.signature===signature?old:{signature,kind:measurement?'measurement':nodes.some(n=>n.latent)?'vertical':'horizontal',scale:'raw',mode:'single',group:groups[0].id,other:groups[1].id,variances:false,covariances:true,digits:3,zoom:100};
      // Restore only on the first rendering of this analysis. Match labels
      // rather than serialized node/group indices; build the canvas locally.
      const saved=p.restoredView;
      if(!state.restoredApplied && saved && saved.stage===p.model && Array.isArray(saved.positions)) {
        const byLabel=new Map(saved.positions.map(n=>[n.label,n]));
        const a=groups.find(g=>g.label===saved.group),b=groups.find(g=>g.label===saved.other);
        if(a&&b&&a.id!==b.id&&byLabel.size===nodes.length&&nodes.every(n=>{
          const q=byLabel.get(n.label);return q&&Number.isFinite(q.x)&&Number.isFinite(q.y);
        })&&['horizontal','vertical',...(measurement?['measurement']:[])].includes(saved.kind)&&
          ['single','compare','difference'].includes(saved.mode)&&['raw','std'].includes(saved.scale)&&
          [2,3,4].includes(saved.digits)&&[70,85,100,125,150].includes(saved.zoom)&&
          ['covariances','variances','wide'].every(k=>typeof saved[k]==='boolean')) {
          Object.assign(state,{kind:saved.kind,mode:saved.mode,scale:saved.scale,group:a.id,other:b.id,
            digits:saved.digits,zoom:saved.zoom,covariances:saved.covariances,variances:saved.variances,wide:saved.wide});
          state.layout=buildLayout(nodes,edges,state.kind);
          nodes.forEach(n=>{const q=byLabel.get(n.label);move(n.id,q.x,q.y);});
          state.restoredApplied=true;
        }
      }
      if(!state.layout)state.layout=buildLayout(nodes,edges,state.kind);
      memo.set(memoKey,state);
      if(memo.size>32)memo.delete(memo.keys().next().value);
      // Send only a small, JSON-encoded view recipe, not SVG or estimates.
      // The R side binds this to the current result token and validates it.
      function publishView() {
        if(!p.stateInput||p.viewToken==null||!window.Shiny||typeof window.Shiny.setInputValue!=='function')return;
        const view={stage:String(p.model),group:groups.find(g=>g.id===state.group).label,
          other:groups.find(g=>g.id===state.other).label,mode:state.mode,scale:state.scale,kind:state.kind,
          digits:state.digits,zoom:state.zoom,covariances:state.covariances,variances:state.variances,wide:!!state.wide,
          positions:nodes.map(n=>({label:n.label,x:state.layout.pos[n.id].x,y:state.layout.pos[n.id].y}))};
        window.Shiny.setInputValue(p.stateInput,JSON.stringify({token:String(p.viewToken),view}),{priority:'event'});
      }
      root.replaceChildren();
      const style=el('style',{},`
        .lvg-group-diagram {font:16px/1.45 system-ui,sans-serif;color:inherit;}
        .lvg-gd-tools {display:flex;flex-wrap:wrap;gap:10px 16px;align-items:flex-end;margin:10px 0;}
        .lvg-gd-field {display:flex;flex-direction:column;gap:4px;font-weight:600;margin:0;min-width:130px;max-width:100%;}
        .lvg-gd-field select {font-size:16px;max-width:100%;min-height:36px;}
        .lvg-gd-check {font-size:16px;font-weight:400;margin:0;display:flex;align-items:center;gap:5px;}
        .lvg-gd-panels {display:flex;flex-wrap:wrap;gap:14px;align-items:flex-start;}
        .lvg-gd-panel {flex:1 1 410px;min-width:0;max-width:100%;border:1px solid #c7d3df;border-radius:8px;padding:10px;overflow:hidden;}
        .lvg-gd-panel header {display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:6px;margin-bottom:8px;}
        .lvg-gd-panel header strong {font-size:18px;overflow-wrap:anywhere;}
        .lvg-gd-panel .btn {font-size:15px;}
        .lvg-gd-scroll {overflow:auto;max-width:100%;max-height:75vh;background:#fff;border-radius:5px;}
        .lvg-gd-scroll svg {display:block;background:white;touch-action:pan-x pan-y;}
        .lvg-gd-node {cursor:move;touch-action:none;outline:none;}
        .lvg-gd-node:focus > rect,.lvg-gd-node:focus > ellipse {stroke:#a35d00;stroke-width:3;}
        .lvg-gd-node:active {cursor:grabbing;}
        .lvg-gd-note {font-size:15px;margin:8px 0;overflow-wrap:anywhere;}
        .lvg-gd-wide:has(> .col-sm-8 .tab-pane.active .lvg-group-diagram) > .col-sm-4 {display:none;}
        .lvg-gd-wide:has(> .col-sm-8 .tab-pane.active .lvg-group-diagram) > .col-sm-8 {width:100%;}
      `);
      root.append(style);
      const tools=el('div',{class:'lvg-gd-tools'}),panels=el('div',{class:'lvg-gd-panels'});
      const notes=el('p',{class:'lvg-gd-note'},'Same layout for all groups. Drag a node or focus it and use the arrow keys (Shift for larger steps). Scroll to see the whole diagram, or adjust zoom. SVG export uses the current layout.');
      const legend=el('p',{class:'lvg-gd-note'},'Rectangles: observed variables; ellipses: latent variables. Single-headed arrows: loadings or regressions; double-headed arrows: covariances (possibly residual). Means, intercepts, thresholds and defined effects are not drawn. NA indicates an unavailable estimate.'+(p.ordinal?' Ordinal loadings refer to underlying latent responses; see Selected estimates for thresholds. Raw scales may differ between invariance stages.':''));
      const inference=el('p',{class:'lvg-gd-note'},'Differences in displayed estimates are descriptive. Use the Fit table for formal equality tests, which concern unstandardized parameters. Equal raw parameters may have different standardized values. The difference panel subtracts second minus first before rounding. Raw comparisons require a defensible common scale, especially for latent and ordinal models.');
      if(p.warnings>0)root.append(el('p',{class:'alert alert-warning'},`This fit has ${p.warnings} warning(s). Consult the Fit table and diagnostics.`));
      root.append(tools,notes,panels,legend,inference);
      let groupSelect,otherSelect,otherField,modeSelect,layoutSelect,zoomSelect;
      const groupOpts=groups.map(g=>[g.id,`${g.label} (n = ${g.n})`]);
      const groupField=field('Group',groupSelect=select(groupOpts,state.group,v=>{state.group=Number(v);if(state.other===state.group)state.other=groups.find(g=>g.id!==state.group).id;refreshOther();render();}));
      function refreshOther() {otherSelect.replaceChildren();groupOpts.filter(([id])=>id!==state.group).forEach(([v,t])=>otherSelect.append(el('option',{value:v},t)));otherSelect.value=String(state.other);otherField.hidden=state.mode==='single';otherField.style.display=state.mode!=='single'?'flex':'none';}
      otherField=field('Second group',otherSelect=select(groupOpts,state.other,v=>{state.other=Number(v);render();}));
      modeSelect=select([['single','One group'],['compare','Compare two groups'],['difference','Two groups + difference (second minus first)']],state.mode,v=>{state.mode=v;refreshOther();render();});
      const layoutOpts=[...(measurement?[['measurement','Compact CFA']]:[]),['horizontal','Left to right'],['vertical','Top to bottom']];
      layoutSelect=select(layoutOpts,state.kind,v=>{state.kind=v;state.layout=buildLayout(nodes,edges,v);render();});
      zoomSelect=select([[70,'70%'],[85,'85%'],[100,'100%'],[125,'125%'],[150,'150%']],state.zoom,v=>{state.zoom=Number(v);render();});
      tools.append(field('Display',modeSelect),groupField,otherField,
        field('Coefficients',select([['raw','Unstandardized'],['std','Fully standardized (std.all)']],state.scale,v=>{state.scale=v;render();})),
        field('Layout',layoutSelect),field('Zoom',zoomSelect),field('Decimals',select([[2,'2'],[3,'3'],[4,'4']],state.digits,v=>{state.digits=Number(v);render();})),
        check('Covariances',state.covariances,v=>{state.covariances=v;render();}),check('Variances',state.variances,v=>{state.variances=v;render();}),
        button('Reset layout',()=>{state.layout=buildLayout(nodes,edges,state.kind);render();}));
      // Use the full results row if the user wants more room. Only the
      // active diagram tab is affected; other tabs keep their original layout.
      const mainCol=root.closest('.col-sm-8'),mainRow=mainCol?.parentElement;
      if(mainRow?.querySelector(':scope > .col-sm-4')&&CSS.supports('selector(:has(*))')) {
        const toggle=button(state.wide?'Show analysis settings':'Expand viewer',()=>{
          state.wide=!state.wide;mainRow.classList.toggle('lvg-gd-wide',state.wide);
          toggle.textContent=state.wide?'Show analysis settings':'Expand viewer';
          toggle.setAttribute('aria-pressed',String(state.wide));publishView();
        });
        toggle.setAttribute('aria-pressed',String(!!state.wide));
        mainRow.classList.toggle('lvg-gd-wide',!!state.wide);tools.append(toggle);
      }
      refreshOther();
      function positioned() {return nodes.map(n=>({...n,...state.layout.pos[n.id]}));}
      function finiteValue(row) {const v=row?.[state.scale];return typeof v==='number'&&Number.isFinite(v)?v:null;}
      function differenceFor(e) {
        const first=finiteValue(rowMap.get(`${e.key}:${state.group}`)),second=finiteValue(rowMap.get(`${e.key}:${state.other}`));
        // Absent or unavailable coefficients are not zero. Subtract before rounding.
        return first===null||second===null||!Number.isFinite(second-first)?null:second-first;
      }
      function labelFor(value, signed=false) {
        if(value===null)return 'NA';
        const v=Math.abs(value)<.5*10**(-state.digits)?0:value;
        return (signed&&v>0?'+':'')+v.toFixed(state.digits);
      }
      const panelState=[];
      function render() {
        panels.replaceChildren();panelState.length=0;
        const ids=state.mode==='single'?[state.group]:[state.group,state.other];
        if(state.mode==='difference')ids.push('difference');
        for(const id of ids) {
          const delta=id==='difference',g=delta?{id,label:`${groups.find(q=>q.id===state.other).label} − ${groups.find(q=>q.id===state.group).label}`,n:null}:groups.find(q=>q.id===id),panel=el('section',{class:'lvg-gd-panel','data-difference':String(delta)}),header=el('header');
          const title=delta?`Difference: ${g.label} (descriptive)`:`${p.grouping}: ${g.label} (n = ${g.n})`;
          const s=svg('svg',{xmlns:NS,role:'img','aria-label':`${p.model}, ${title}`,viewBox:`0 0 ${state.layout.width} ${state.layout.height+64}`,width:Math.round(state.layout.width*state.zoom/100),height:Math.round((state.layout.height+64)*state.zoom/100),'font-family':'Arial, sans-serif'});
          const scroll=el('div',{class:'lvg-gd-scroll'});scroll.append(s);
          header.append(el('strong',{},title),button('Download SVG',()=>download(s,g)));
          panel.append(header,scroll);panels.append(panel);panelState.push({g,s,delta});
          let drag=null;
          const point=e=>{const matrix=s.getScreenCTM();return matrix?new DOMPoint(e.clientX,e.clientY).matrixTransform(matrix.inverse()):null;};
          s.addEventListener('pointerdown',e=>{
            const target=e.target.closest('.lvg-gd-node');if(!target||e.button!==0)return;
            const q=point(e);if(!q)return;
            const nid=Number(target.dataset.node),pos=state.layout.pos[nid];
            drag={id:nid,dx:q.x-pos.x,dy:q.y-pos.y,pointer:e.pointerId};
            s.setPointerCapture(e.pointerId);e.preventDefault();
          });
          s.addEventListener('pointermove',e=>{if(!drag||e.pointerId!==drag.pointer)return;const q=point(e);if(!q)return;move(drag.id,q.x-drag.dx,q.y-drag.dy);paintAll();});
          const stop=e=>{if(drag&&e.pointerId===drag.pointer){drag=null;if(s.hasPointerCapture(e.pointerId))s.releasePointerCapture(e.pointerId);publishView();}};
          s.addEventListener('pointerup',stop);s.addEventListener('pointercancel',stop);
        }
        paintAll();publishView();
      }
      function move(id,x,y) {
        const n=nodeMap.get(id);state.layout.pos[id]={x:Math.max(n.w/2+28,Math.min(state.layout.width-n.w/2-28,x)),y:Math.max(n.h/2+82,Math.min(state.layout.height-n.h/2-25,y))};
      }
      function paintAll(focusId,focusSvg) {for(const panel of panelState)paint(panel);if(focusId!==undefined)focusSvg?.querySelector(`[data-node="${focusId}"]`)?.focus();}
      function paint({s,g,delta}) {
        s.replaceChildren();
        const W=state.layout.width,H=state.layout.height+64;
        s.append(svg('title',{},`${p.model} - ${delta?'Difference (second minus first)':p.grouping}: ${g.label}`),svg('desc',{},delta?'Descriptive coefficient differences (second group minus first group). Not significance tests. NA means an estimate is unavailable.':'Group-specific estimates on a shared path diagram; not a statistical test of differences.'),svg('rect',{width:W,height:H,fill:'#ffffff'}));
        // Embedded title/scale make the exported SVG self-contained.
        s.append(svg('text',{x:W/2,y:24,'text-anchor':'middle','font-size':18,'font-weight':700,fill:'#18344f'},`${p.model} | ${delta?'Difference':p.grouping}: ${g.label}`),svg('text',{x:W/2,y:47,'text-anchor':'middle','font-size':15,fill:'#43566a'},`${delta?'Second minus first | descriptive':`n = ${g.n}`} | ${state.scale==='raw'?'Unstandardized':'Fully standardized (std.all)'}${state.variances?' | variances shown':''}`));
        const list=positioned(),byId=new Map(list.map(n=>[n.id,n]));
        const visible=edges.filter(e=>(e.from===e.to?state.variances:e.op!=='~~'||state.covariances)&&(delta?(rowMap.has(`${e.key}:${state.group}`)||rowMap.has(`${e.key}:${state.other}`)):rowMap.has(`${e.key}:${g.id}`)));
        const edgeLayer=svg('g'),labelLayer=svg('g'),nodeLayer=svg('g');
        s.append(edgeLayer,labelLayer,nodeLayer);
        let hidden=0;
        for(const e of visible) {
          const a=byId.get(e.from),b=byId.get(e.to),row=rowMap.get(`${e.key}:${g.id}`),geo=geometry(a,b,e,visible,state.kind,list);
          if(!geo){hidden++;continue;}
          const color=e.op==='~~'?(e.from===e.to?colors.variance:colors.covariance):e.op==='=~'?colors.loading:colors.regression;
          const value=delta?differenceFor(e):finiteValue(row);
          const val=labelFor(value,delta);
          const edge=svg('g',{'data-edge':e.key,'data-value':val,'aria-label':`${a.label} ${e.op==='~~'?'covariance with':'to'} ${b.label}: ${val}`});
          edge.append(svg('title',{},`${a.label} ${e.op==='~~'?'~~':'→'} ${b.label}: ${val}`),svg('path',{d:geo.d,fill:'none',stroke:color,'stroke-width':2.3,'stroke-linecap':'round'}));
          for(const head of geo.heads)edge.append(svg('polygon',{points:head.map(p=>`${p.x.toFixed(2)},${p.y.toFixed(2)}`).join(' '),fill:color,'data-head':'1'}));
          edgeLayer.append(edge);
          // White halo gives contrast even when a label crosses another path.
          labelLayer.append(svg('text',{x:geo.label.x,y:geo.label.y+5,'text-anchor':'middle','font-size':18,'font-weight':600,fill:color,stroke:'#ffffff','stroke-width':5,'stroke-linejoin':'round','paint-order':'stroke','data-label':e.key},val));
        }
        for(const n of list) {
          const grp=svg('g',{class:'lvg-gd-node','data-node':n.id,tabindex:0,role:'group','aria-label':`${n.label}, ${n.latent?'latent':'observed'} variable. Arrow keys move node.`});
          const shape=n.latent?svg('ellipse',{cx:n.x,cy:n.y,rx:n.w/2,ry:n.h/2,fill:'#e8f3f8',stroke:'#17658c','stroke-width':2}):svg('rect',{x:n.x-n.w/2,y:n.y-n.h/2,width:n.w,height:n.h,rx:4,fill:'#f1f5f9',stroke:'#314c67','stroke-width':2});
          grp.append(shape,svg('text',{x:n.x,y:n.y+5,'font-size':17,'font-weight':600,'text-anchor':'middle',fill:'#1f3650'},n.label));
          grp.addEventListener('keydown',e=>{const shifts={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]};if(!shifts[e.key])return;e.preventDefault();const [dx,dy]=shifts[e.key],step=e.shiftKey?24:6;move(n.id,n.x+dx*step,n.y+dy*step);paintAll(n.id,s);publishView();});
          nodeLayer.append(grp);
        }
        if(hidden)s.append(svg('text',{x:W/2,y:H-36,'text-anchor':'middle','font-size':15,fill:'#9b4b00'},`${hidden} relation(s) hidden: arrowheads obstructed. Move nodes apart; see Selected estimates.`));
        s.append(svg('text',{x:W/2,y:H-13,'text-anchor':'middle','font-size':13,fill:'#43566a'},delta?'Descriptive difference only; not a significance test. Check scale comparability.':'Group-specific estimates; equality tests are reported in Fit table.'));
      }
      function download(s,g) {
        const copy=s.cloneNode(true);copy.setAttribute('width',state.layout.width);copy.setAttribute('height',state.layout.height+64);
        copy.querySelectorAll('[tabindex]').forEach(n=>n.removeAttribute('tabindex'));
        const blob=new Blob(['<?xml version="1.0" encoding="UTF-8"?>\n',new XMLSerializer().serializeToString(copy)],{type:'image/svg+xml;charset=utf-8'});
        const url=URL.createObjectURL(blob),a=el('a',{href:url,download:`${cleanName(p.model)}-${cleanName(p.grouping)}-${g.id==='difference'?'difference-':''}${cleanName(g.label)}-${state.scale}.svg`});
        document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
      }
      render();
    } catch(e) {root.replaceChildren(el('p',{class:'alert alert-warning'},`Cannot display this diagram: ${e.message}`));}
  }
  function scan() {document.querySelectorAll('.lvg-group-diagram[data-payload]:not([data-ready])').forEach(init);}
  const start=()=>{scan();new MutationObserver(records=>{if(records.some(r=>r.addedNodes.length))scan();}).observe(document.body,{childList:true,subtree:true});};
  if(document.body)start();else document.addEventListener('DOMContentLoaded',start,{once:true});
})();
