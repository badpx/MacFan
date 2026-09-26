const {chromium}=require('/Users/kanedong/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const path=require('path');
const assert=require('assert');
(async()=>{
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'});
try {
const page=await browser.newPage({viewport:{width:1440,height:1200},deviceScaleFactor:2,colorScheme:'light'});
const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto('file://'+path.join(__dirname,'MacFan-Design-Board.html'));
await page.evaluate(()=>document.fonts.ready);
await page.screenshot({path:path.join(__dirname,'MacFan-Design-Board.png'),fullPage:true});
for(const [i,name] of ['Light','Dark','Settings'].entries())await page.locator('#macfan-concept-'+i+' .mf-scene').screenshot({path:path.join(__dirname,'MacFan-'+name+'.png')});
assert.equal(await page.locator('[data-lucide]:not(svg)').count(),0,'All icons must render');
const root=page.locator('#macfan-concept-0');
assert.equal(await root.getByRole('tab').count(),2,'Overview and configuration tabs retained');
assert.equal(await root.locator('.mf-head button').count(),0,'No settings icon');
assert(!(await root.innerText()).includes('F1'),'No per-fan labels');
await root.getByRole('tab',{name:'菜单栏设置',exact:true}).click();
assert.equal(await root.getByRole('tab',{name:'菜单栏设置',exact:true}).getAttribute('aria-selected'),'true');
await root.getByRole('checkbox',{name:'在菜单栏显示GPU',exact:true}).check();
assert.equal(await root.locator('[data-count]').innerText(),'菜单栏 · 5 项');
assert((await root.locator('[data-config-hint]').innerText()).includes('空间不足'));
for(const input of await root.locator('[data-metric]').all())await input.uncheck();
assert.equal(await root.locator('.mf-bar-items svg').count(),1);
await root.locator('[data-quit]').click();
assert.equal(await root.getByRole('dialog').isVisible(),true);
await page.keyboard.press('Escape');
assert.equal(await root.getByRole('dialog').isVisible(),false);
await root.locator('[data-quit]').click();
await root.locator('[data-confirm]').click();
assert.equal(await root.locator('.mf-closed').isVisible(),true);
await root.locator('[data-reopen]').click();
assert.equal(await root.locator('.mf-window').isVisible(),true);
await page.goto('file://'+path.join(__dirname,'MacFan-States.html'));
await page.screenshot({path:path.join(__dirname,'MacFan-States.png'),fullPage:true});
assert.equal(await page.locator('#macfan-concept-2 [data-download]').innerText(),'—');
assert.equal(await page.locator('#macfan-concept-0 [data-fan]').innerText(),'2000','1800 and 2200 RPM average');
assert.equal(await page.locator('#macfan-concept-1 [data-memory]').getAttribute('data-hot'),'true');
await page.addInitScript(()=>{window.Tweak=class{constructor(options){window.designTest={render:options.onChange,fields:{}}}addSelect(object,key){window.designTest.fields[key]=object}addSlider(object,key){window.designTest.fields[key]=object}}});
await page.goto('file://'+path.join(__dirname,'MacFan-Prototype.html'));
const ramp=await page.evaluate(()=>{
const t=window.designTest;const colors=[];
for(const [temperature,memory] of [[74.9,79.9],[75,80],[80,85],[85,90]]){
t.fields.temperature.temperature=temperature;t.fields.memory.memory=memory;t.render();
colors.push({temperature:getComputedStyle(document.querySelector('.mf-temperature')).color,memory:getComputedStyle(document.querySelector('[data-memory-value]')).color});
}
t.fields.temperature.temperature=51.9;t.fields.memory.memory=75.625;t.render();
return colors;
});
assert.equal(new Set(ramp.map(x=>x.temperature)).size,4,'Temperature uses continuous color');
assert.equal(new Set(ramp.map(x=>x.memory)).size,4,'Memory uses continuous color');
for(const width of [736,432,320]){
await page.setViewportSize({width,height:1000});
const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
assert(!overflow,'No overflow at '+width);
for(const name of ['系统概览','菜单栏设置']){
await page.getByRole('tab',{name,exact:true}).click();
const clipped=await page.locator('.mf-window').evaluate(el=>[...el.querySelectorAll('*')].filter(n=>n.getClientRects().length&&n.scrollWidth>n.clientWidth+2&&getComputedStyle(n).display!=='inline'&&!['svg','path','circle','line','rect'].includes(n.tagName.toLowerCase())).map(n=>n.className));
assert.deepEqual(clipped,[],'No clipped content at '+width+' / tab '+name);
}
}
assert.deepEqual(errors,[],'No JavaScript errors');
console.log(JSON.stringify({passed:true,checks:['overview and configuration tabs','refresh text without settings icon','average fan speed','continuous temperature and memory colors','overflow hint','icon fallback','exit and cancel','320/432/736 widths','no script errors'],outputs:__dirname}));
}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
