(()=>{
const root=document.getElementById('macfan-concept');
const metrics=[['cpu','CPU','20.1%','CPU'],['gpu','GPU','4%','GPU'],['memory','内存','76%','MEM'],['disk','磁盘','33%','DISK'],['temperature','温度','52°','TEMP'],['fan','风扇','0','RPM'],['network','网络','↑10.2K','↓32.1K']];
let selected=new Set(['cpu','memory','temperature','network']);
const design={appearance:'system',status:'normal',radius:18,temperature:51.9,memory:75.625};
function icons(){globalThis.lucide?.createIcons({attrs:{width:16,height:16}})}
function persist(){window.openai?.setWidgetState?.({modelContent:{page:root.dataset.page,menuBarMetrics:[...selected],launchAtLogin:root.querySelector('[data-login]').checked},privateContent:{...design}}).catch(()=>{})}
function showPage(value,save=true){root.dataset.page=value;root.querySelectorAll('.mf-tab').forEach(b=>b.setAttribute('aria-selected',String(b.dataset.page===value)));root.querySelector('#mf-overview').hidden=value!=='overview';root.querySelector('#mf-config').hidden=value!=='config';if(save)persist()}
const metricIcons=['cpu','microchip','memory-stick','hard-drive','thermometer','fan','arrow-down-up'];
metrics.forEach(([id,label],index)=>{const row=document.createElement('label');row.className='mf-option';const name=document.createElement('span');name.className='mf-option-name';const icon=document.createElement('i');icon.dataset.lucide=metricIcons[index];icon.setAttribute('aria-hidden','true');name.append(icon,document.createTextNode(label));const input=document.createElement('input');input.className='mf-switch cursor-interaction';input.type='checkbox';input.dataset.metric=id;input.setAttribute('aria-label','在菜单栏显示'+label);row.append(name,input);root.querySelector('[data-options]').append(row)});
root.querySelectorAll('[data-meter]').forEach(el=>{const n=Number(el.dataset.meter)/100*20;el.innerHTML=Array.from({length:20},(_,i)=>`<b class="${i+1<=n?'on':i<n?'partial':''}" style="--fill:${Math.round((n-i)*100)}%"></b>`).join('')});
function renderBar(){
  const chosen=metrics.filter(m=>selected.has(m[0]));
  root.querySelector('.mf-bar-items').innerHTML=chosen.length?chosen.slice(0,4).map(([id,label,top,bottom])=>{
    if(id==='temperature')top=Math.round(design.temperature)+'°';
    if(id==='memory')top=Math.round(design.memory)+'%';
    if(id==='network'&&design.status==='unavailable')bottom='↓—';
    if(id==='fan')top=root.querySelector('[data-fan]').textContent;
    return `<span class="mf-bar-item ${id==='network'?'net':''}"><span>${top}</span><small>${bottom}</small></span>`;
  }).join(''):'<i data-lucide="fan" aria-label="MacFan"></i>';
  root.querySelector('[data-count]').textContent=`菜单栏 · ${selected.size} 项`;
  root.querySelector('[data-selected-count]').textContent=`${selected.size} 项已开启`;
  root.querySelectorAll('[data-metric]').forEach(input=>input.checked=selected.has(input.dataset.metric));
  root.querySelector('[data-config-hint]').textContent=chosen.length>4?'预览空间不足，部分指标暂时隐藏；已保留全部选择。':chosen.length===0?'所有指标已关闭，菜单栏仅显示 MacFan 图标。':'开启后，指标会显示在顶部菜单栏。关闭所有指标时，仅显示 MacFan 图标。';
  icons();
}
function heat(value,start,end){return value<start?null:Math.min(1,Math.max(0,(value-start)/(end-start)))}
function applyHeat(name,value,start,end){const level=heat(value,start,end);root.style.setProperty('--mf-'+name+'-color',level===null?'var(--mf-text)':`color-mix(in srgb,var(--mf-heat-start),var(--mf-heat-end) ${level*100}%)`);return level}
function renderDesign(){
  root.style.colorScheme=design.appearance==='system'?'light dark':design.appearance;
  root.style.setProperty('--mf-radius',design.radius+'px');
  const missing=design.status==='unavailable';
  const tempHeat=applyHeat('temp',design.temperature,75,85);
  const memoryHeat=applyHeat('memory',design.memory,80,90);
  root.querySelector('.mf-temperature').dataset.hot=String(tempHeat!==null);
  root.querySelector('[data-memory]').dataset.hot=String(memoryHeat!==null);
  root.querySelector('[data-temp]').textContent=Number(design.temperature).toFixed(1);
  root.querySelector('[data-temp-note]').textContent=tempHeat===null?'传感器读数':tempHeat<1?'温度偏高':'温度过高';
  root.querySelector('[data-memory-value]').textContent=(design.memory*32/100).toFixed(1);
  root.querySelector('[data-memory-free]').textContent=`可用 ${(32-design.memory*32/100).toFixed(1)} GB`;
  root.querySelector('[data-memory-used]').textContent=`已用 ${Math.round(design.memory)}%${memoryHeat===null?'':memoryHeat<1?' · 偏高':' · 很高'}`;
  root.querySelector('[data-memory] .mf-track').setAttribute('aria-valuenow',design.memory);
  root.querySelector('[data-memory] .mf-track>span').style.width=design.memory+'%';
  // Two complete sensor readings are required for a two-fan average.
  const rpms=missing?[null,null]:tempHeat===null?[0,0]:[1800,2200];
  const average=rpms.every(v=>typeof v==='number')?rpms.reduce((a,b)=>a+b,0)/rpms.length:null;
  root.querySelector('[data-fan]').textContent=average===null?'—':Math.round(average).toString();
  root.querySelector('[data-fan-note]').textContent=average===null?'平均转速不可用':average===0?'平均转速 · 停转':'平均转速';
  root.querySelector('[data-download]').textContent=missing?'—':'32.1';
  root.querySelector('[data-download-unit]').textContent=missing?'暂不可用':'KB/s';
  const banner=root.querySelector('[data-banner]');banner.hidden=!missing;banner.textContent='部分数据暂不可用，其余指标继续更新。';
  renderBar();
}
root.querySelectorAll('.mf-tab').forEach(button=>button.addEventListener('click',()=>showPage(button.dataset.page)));
root.querySelector('[data-login]').addEventListener('change',persist);
root.querySelectorAll('[data-metric]').forEach(input=>input.addEventListener('change',()=>{input.checked?selected.add(input.dataset.metric):selected.delete(input.dataset.metric);renderBar();persist()}));
const dialog=root.querySelector('.mf-dialog');
root.querySelector('[data-quit]').addEventListener('click',()=>{dialog.hidden=false;root.querySelector('[data-cancel]').focus()});
function closeDialog(){dialog.hidden=true;root.querySelector('[data-quit]').focus()}
root.querySelector('[data-cancel]').addEventListener('click',closeDialog);
root.querySelector('[data-confirm]').addEventListener('click',()=>{dialog.hidden=true;root.querySelector('.mf-window').hidden=true;root.querySelector('.mf-closed').hidden=false;root.querySelector('[data-reopen]').focus()});
root.querySelector('[data-reopen]').addEventListener('click',()=>{root.querySelector('.mf-window').hidden=false;root.querySelector('.mf-closed').hidden=true;root.querySelector('.mf-tab[aria-selected=true]').focus()});
root.addEventListener('keydown',e=>{if(!dialog.hidden){if(e.key==='Escape')closeDialog();if(e.key==='Tab'){const a=root.querySelector('[data-cancel]'),b=root.querySelector('[data-confirm]');if(e.shiftKey&&document.activeElement===a){e.preventDefault();b.focus()}else if(!e.shiftKey&&document.activeElement===b){e.preventDefault();a.focus()}}}else if(e.target.matches('.mf-tab')&&['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();showPage(root.dataset.page==='overview'?'config':'overview');root.querySelector('.mf-tab[aria-selected=true]').focus()}});
function restore(saved){
  if(!saved)return;
  const m=saved.modelContent||{},p=saved.privateContent||{};
  if(Array.isArray(m.menuBarMetrics))selected=new Set(m.menuBarMetrics.filter(id=>metrics.some(v=>v[0]===id)));
  if(['light','dark','system'].includes(p.appearance))design.appearance=p.appearance;
  if(['normal','unavailable'].includes(p.status))design.status=p.status;
  for(const [key,min,max] of [['temperature',30,100],['memory',0,100],['radius',12,24]])if(Number.isFinite(p[key]))design[key]=Math.min(max,Math.max(min,p[key]));
  if(typeof m.launchAtLogin==='boolean')root.querySelector('[data-login]').checked=m.launchAtLogin;
  showPage(m.page==='config'?'config':'overview',false);renderDesign();
}
restore(window.openai?.widgetState);renderDesign();
window.addEventListener('openai:set_globals',e=>restore(e.detail?.globals?.widgetState));
if(globalThis.Tweak){
  const tweak=new Tweak({container:root,onChange:()=>{renderDesign();persist()}});
  tweak.addSelect(design,'appearance',{label:'外观',options:[{label:'跟随系统',value:'system'},{label:'浅色',value:'light'},{label:'深色',value:'dark'}]});
  tweak.addSlider(design,'temperature',{label:'温度 · 连续色阶',min:30,max:100,step:.1,unit:'°C'});
  tweak.addSlider(design,'memory',{label:'内存 · 连续色阶',min:0,max:100,step:1,unit:'%'});
  tweak.addSelect(design,'status',{label:'读取状态',options:[{label:'可用',value:'normal'},{label:'部分不可用',value:'unavailable'}]});
}
})();
