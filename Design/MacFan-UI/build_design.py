from pathlib import Path
import re

OUT = Path(__file__).parent
SOURCE = Path('/Users/kanedong/.codex/visualizations/2026/09/25/01a0d959-c934-72d0-8b39-601478a7e400/macfan-ui.html')
fragment = SOURCE.read_text()
lucide = Path('/Users/kanedong/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/lucide/dist/umd/lucide.min.js').read_text()
copies = []
for index, (theme, title, subtitle) in enumerate([
    ('light', '01 / 浅色 · 系统概览', '轻量层次，让数值成为视线的第一落点。'),
    ('dark', '02 / 深色 · 系统概览', '柔和对比，为长时间使用保留舒适度。'),
    ('light', '03 / 菜单栏设置', '保留配置标签页，让查看与选择各自清晰。'),
]):
    part = fragment.replace('macfan-concept', f'macfan-concept-{index}')
    for original in ['mf-overview', 'mf-config', 'mf-tab-overview', 'mf-tab-config']:
        part = part.replace(original, f'{original}-{index}')
    part = part.replace("appearance:'system'", f"appearance:'{theme}'")
    if index == 2:
        part = part.replace('restore(window.openai?.widgetState);renderDesign();', "restore(window.openai?.widgetState);renderDesign();showPage('config',false);")
    copies.append(f'<section class="board-column"><div class="column-label">{title}</div>{part}<div class="column-note">{subtitle}</div></section>')

style = '''
*{box-sizing:border-box}html,body{margin:0}body{font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;background:#ECEEEB;color:#202A27}.board{width:1440px;padding:54px 56px 42px;margin:auto}.eyebrow{font-size:12px;font-weight:600;letter-spacing:2px;color:#537568;display:flex;justify-content:space-between}.eyebrow span:last-child{letter-spacing:.8px;color:#68716B;font-weight:400}.hero{display:flex;justify-content:space-between;align-items:flex-end;margin:28px 0 42px}.hero h1{font-size:60px;line-height:1.05;font-weight:600;letter-spacing:-3px;margin:0}.hero h1 span{font-size:36px;letter-spacing:-1px;font-weight:400;margin-left:14px}.hero p{font-size:14px;line-height:1.8;color:#626E67;margin:0;max-width:390px}.board-columns{display:grid;grid-template-columns:repeat(3,1fr);gap:32px}.column-label{font-size:12px;letter-spacing:1px;color:#617067;margin-bottom:15px}.column-note{font-size:12px;color:#69736C;margin:4px 22px 0}.board-column>[id^=macfan-concept]{padding:0 0 20px}.tokens{margin-top:42px;padding-top:24px;border-top:1px solid #CDD4CD;display:grid;grid-template-columns:1.1fr 1fr 1.1fr;gap:40px}.token-title{font-size:11px;letter-spacing:1.2px;color:#6A766E;margin-bottom:14px}.swatches{display:flex;gap:10px}.swatch{width:40px;height:32px;border-radius:7px}.token-detail{font-size:12px;line-height:1.8;margin-top:10px;color:#56645A}.typography{font-size:28px;letter-spacing:-.7px;line-height:32px;font-weight:550}.typography span{font-size:13px;letter-spacing:0;font-weight:400;margin-left:12px}.status-row{display:flex;gap:8px}.status{padding:7px 10px;border-radius:7px;background:#F8FAF7;font-size:11px;white-space:nowrap}.status.warn{color:#925B0D;background:#F5EBD8}.status.error{color:#B43E39;background:#F9E4DF}.board-footer{margin-top:32px;border-top:1px solid #CDD4CD;padding-top:16px;display:flex;justify-content:space-between;font-size:10px;letter-spacing:1px;color:#728076}button,input{cursor:pointer!important}
'''
html = '<!doctype html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>MacFan · UI Design</title><style>'+style+'</style></head><body><script>'+lucide+'</script><main class="board"><div class="eyebrow">MACFAN / INTERFACE STUDY<span>DESIGN SYSTEM 01 · macOS</span></div><div class="hero"><h1>安静地，<span>看见每一刻。</span></h1><p>从一列读数，到有层次的系统概览。<br>轻巧地驻留菜单栏，让每一次查看都清晰、从容。</p></div><div class="board-columns">'+''.join(copies)+'''</div>
<section class="tokens"><div><div class="token-title">COLOR / 中性底色 · 青绿强调</div><div class="swatches"><div class="swatch" style="background:#202225"></div><div class="swatch" style="background:#2B2D31"></div><div class="swatch" style="background:#FFFFFF"></div><div class="swatch" style="background:#147A67"></div><div class="swatch" style="background:#71D5BA"></div></div><div class="token-detail">风扇仅显示平均转速，不区分单个风扇。<br>保留概览与配置标签页，右上角显示刷新周期。</div></div><div><div class="token-title">TYPE & SPACE / 数字优先</div><div class="typography">20.1<span>SF Pro · 等宽数字</span></div><div class="token-detail">384 pt 面板 / 20 pt 留白 / 12 pt 卡片圆角<br>30 pt 核心读数 / 13 pt 正文 / 11 pt 辅助</div></div><div><div class="token-title">HEAT / 随读数连续增强的橙色</div><div style="height:12px;border-radius:6px;background:linear-gradient(to right,#AD681F,#C3451A)"></div><div class="token-detail">温度 75 → 85 °C / 内存 80 → 90%<br>数值、单位与比例条同步增强，保留文字提示。</div></div></section>
<footer class="board-footer"><span>MACFAN · QUIET CLARITY</span><span>示例数据 · 非实时监测 · 高精度界面提案</span><span>01 / 01</span></footer></main></body></html>'''
(OUT/'MacFan-Design-Board.html').write_text(html)
states = html
for index, state in enumerate(['warning', 'critical', 'unavailable']):
    old = copies[index]
    new = old.replace("showPage('config',false);", "showPage('overview',false);")
    if state == 'unavailable':
        new = new.replace("status:'normal'", "status:'unavailable'")
    else:
        new = new.replace('temperature:51.9,memory:75.625', 'temperature:78.2,memory:83' if state == 'warning' else 'temperature:87.4,memory:94')
    new = re.sub(r'<div class="column-label">.*?</div>', '<div class="column-label">'+['01 / 温度与内存偏高', '02 / 热度继续增强', '03 / 数据不可用'][index]+'</div>', new, count=1)
    new = re.sub(r'<div class="column-note">.*?</div>', '<div class="column-note">'+['橙色强调数值与比例；风扇显示平均值。', '热度连续增强，不跳变为固定颜色档位。', '无法读取不等于零，其他数据继续显示。'][index]+'</div>', new, count=1)
    states = states.replace(old, new)
states = states.replace('安静地，<span>看见每一刻。', '每一种状态，<span>都有清晰表达。')
(OUT/'MacFan-States.html').write_text(states)
(OUT/'MacFan-Prototype.html').write_text('<!doctype html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>MacFan Prototype</title><style>body{margin:0;padding:32px 16px;background:#ECEEEB}body>p{font:12px -apple-system,sans-serif;text-align:center;color:#626972}</style></head><body><script>'+lucide+'</script>'+fragment+'<p>MacFan 高精度交互提案 · 示例数据，非实时监测</p></body></html>')
print(OUT/'MacFan-Design-Board.html')
