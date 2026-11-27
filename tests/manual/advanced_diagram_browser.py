"""Optional browser test with synthetic coefficients (not actual lavaan results).
From package root: python tests/manual/advanced_diagram_browser.py [preview-folder]
Requires playwright and installed Chromium; optional CHROMIUM environment variable.
"""
import html
import json
import os
from pathlib import Path
import shutil
import sys
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
JS = (ROOT / 'inst/www/advanced-group-diagram.js').read_text(encoding='utf-8')

def cfa_fixture():
    nodes = [{'id': i+1, 'label': label, 'latent': i < 2} for i, label in enumerate(['f1','f2','x1','x2','x3','x4','x5','x6'])]
    rows = []
    for group in (1,2,3):
        for fr, to, raw, std in [(1,3,1,.78),(1,4,.64,.53),(1,5,.73,.61),(2,6,1,.84),(2,7,1.14,.86),(2,8,.94,.81)]:
            rows.append(dict(from_=fr,to=to,op='=~',group=group,raw=raw if raw==1 else raw+.08*(group-1),std=std-.025*(group-1)))
        rows.append(dict(from_=1,to=2,op='~~',group=group,raw=.51+.1*group,std=.39+.06*group))
        rows.append(dict(from_=7,to=8,op='~~',group=group,raw=-.12,std=-.17))
        for node in nodes:
            rows.append(dict(from_=node['id'],to=node['id'],op='~~',group=group,raw=.42,std=.31))
    for row in rows: row['from']=row.pop('from_')
    # Keep raw and standardized missing coefficients distinct from actual zero.
    rows[1]['std'] = None
    return dict(model='Configural',grouping='sex',warnings=0,nodes=nodes,groups=[dict(id=i,label=str(i),n=70+i) for i in (1,2,3)],rows=rows)

def path_fixture():
    nodes=[dict(id=i+1,label=n,latent=False) for i,n in enumerate(['SSE','Soutien','Motivation','Effort','Reussite'])]
    rows=[dict(**{'from':a,'to':b},op=op,group=g,raw=v+.05*(g-1),std=v-.02*(g-1)) for g in (1,2) for a,b,op,v in [(1,3,'~',.31),(2,3,'~',.43),(3,4,'~',.57),(4,5,'~',.53),(1,2,'~~',.28),(1,5,'~',.20)]]
    return dict(model='Free regressions',grouping='g',warnings=1,nodes=nodes,groups=[dict(id=1,label='A <test>',n=200),dict(id=2,label='B',n=199)],rows=rows)

def markup(payload):
    return '<div id="diagram-output" class="shiny-bound-output"><div class="lvg-group-diagram" data-payload="'+html.escape(json.dumps(payload), quote=True)+'"></div></div>'

def head_check(page):
    return page.evaluate('''() => {
      let count=0; const bad=[];
      for(const s of document.querySelectorAll('.lvg-gd-panel svg')) {
        const nodes=[...s.querySelectorAll('[data-node]')].map(n=>n.firstElementChild);
        for(const p of s.querySelectorAll('[data-head]')) {
          count++;
          for(const [x,y] of p.getAttribute('points').split(' ').map(q=>q.split(',').map(Number))) {
            for(const n of nodes) {
              const a=k=>Number(n.getAttribute(k));
              const inside=n.tagName==='ellipse'?((x-a('cx'))/a('rx'))**2+((y-a('cy'))/a('ry'))**2<=1:x>=a('x')&&x<=a('x')+a('width')&&y>=a('y')&&y<=a('y')+a('height');
              if(inside)bad.push([p.parentElement.getAttribute('data-edge'),x,y]);
            }
          }
        }
      }return {count,bad};
    }''')

def main():
    output=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    if output: output.mkdir(parents=True,exist_ok=True)
    with sync_playwright() as pw:
        browser=pw.chromium.launch(executable_path=os.environ.get('CHROMIUM') or shutil.which('chromium'),headless=True,args=['--no-sandbox'])
        page=browser.new_page(viewport={'width':1500,'height':1050},accept_downloads=True)
        page.set_default_timeout(5000)
        errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        page.set_content('<html><body style="font-family:Arial;margin:20px">'+markup(cfa_fixture())+'<script>'+JS+'</script></body></html>')
        page.wait_for_selector('.lvg-gd-panel svg')
        assert page.locator('.lvg-gd-panel').count()==1
        assert page.locator('[data-edge="1:=~:3"]').get_attribute('data-value')=='1.000'
        assert page.locator('[data-edge="1:=~:4"]').get_attribute('data-value')=='0.640'
        page.get_by_label('Group',exact=True).select_option('2')
        assert page.locator('[data-edge="1:=~:4"]').get_attribute('data-value')=='0.720'
        page.get_by_label('Coefficients',exact=True).select_option('std')
        assert page.locator('[data-edge="1:=~:3"]').get_attribute('data-value')=='0.755'
        page.get_by_label('Group',exact=True).select_option('1')
        assert page.locator('[data-edge="1:=~:4"]').get_attribute('data-value')=='NA'
        page.get_by_label('Coefficients',exact=True).select_option('raw')
        page.get_by_label('Display',exact=True).select_option('compare')
        assert page.locator('.lvg-gd-panel').count()==2
        page.get_by_label('Second group',exact=True).select_option('3')
        assert page.locator('.lvg-gd-panel').nth(1).locator('[data-edge="1:=~:4"]').get_attribute('data-value')=='0.800'
        head_total=0
        for layout in ['measurement','horizontal','vertical']:
            page.get_by_label('Layout',exact=True).select_option(layout)
            for loops in [False,True]:
                page.get_by_label('Variances',exact=True).set_checked(loops)
                r=head_check(page);head_total+=r['count'];assert not r['bad'],(layout,loops,r)
        page.get_by_label('Layout',exact=True).select_option('measurement')
        page.get_by_label('Variances',exact=True).uncheck()
        node=page.locator('.lvg-gd-panel').first.locator('[data-node="1"]')
        before=node.locator('ellipse').get_attribute('cx');node.focus();page.keyboard.press('Shift+ArrowRight')
        xs=page.locator('[data-node="1"] ellipse').evaluate_all('(x)=>x.map(n=>Number(n.getAttribute("cx")))')
        assert xs==[float(before)+24]*2,xs
        page.get_by_role('button',name='Reset layout').click()
        assert page.locator('.lvg-gd-panel').first.locator('[data-node="1"] ellipse').get_attribute('cx')==before
        # Pointer drag synchronizes the layouts without changing estimates.
        node=page.locator('.lvg-gd-panel').first.locator('[data-node="1"]');node.scroll_into_view_if_needed()
        b=node.bounding_box();page.mouse.move(b['x']+b['width']/2,b['y']+b['height']/2);page.mouse.down();page.mouse.move(b['x']+b['width']/2+38,b['y']+b['height']/2+20,steps=5);page.mouse.up()
        xs=page.locator('[data-node="1"] ellipse').evaluate_all('(x)=>x.map(n=>Number(n.getAttribute("cx")))')
        assert xs[0]>float(before)+20 and abs(xs[0]-xs[1])<.01,xs
        page.get_by_role('button',name='Reset layout').click()
        page.get_by_label('Zoom',exact=True).select_option('85');page.get_by_label('Decimals',exact=True).select_option('2')
        assert page.locator('[data-edge="1:=~:3"]').first.get_attribute('data-value')=='1.00'
        with page.expect_download() as dl:page.get_by_role('button',name='Download SVG').first.click()
        assert dl.value.suggested_filename.endswith('.svg')
        text=dl.value.path().read_text(encoding='utf-8');assert 'Configural | sex: 1' in text and 'Unstandardized' in text and '<polygon' in text
        if output:
            dl.value.save_as(output/'diagramme-exemple.svg')
            page.get_by_label('Second group',exact=True).select_option('2')
            page.get_by_label('Zoom',exact=True).select_option('100')
            page.evaluate('window.scrollTo(0,0)');page.screenshot(path=str(output/'Apercu_diagrammes_multigroupes.png'),full_page=True)
            page.get_by_label('Second group',exact=True).select_option('3')
        # Mimic a Shiny renderUI replacement, with a different stage but same graph.
        p=cfa_fixture();p['model']='Metric';p['rows'][1]['raw']=.66
        page.locator('#diagram-output').evaluate('(e,x)=>e.innerHTML=x',markup(p).split('class="shiny-bound-output">',1)[1].rsplit('</div>',1)[0]);page.wait_for_selector('.lvg-gd-panel svg')
        assert page.get_by_label('Display',exact=True).input_value()=='compare'
        assert page.locator('[data-edge="1:=~:4"]').first.get_attribute('data-value')=='0.66'
        # Different topology must reset layout; malicious-looking text stays text.
        p=path_fixture();page.locator('#diagram-output').evaluate('(e,x)=>e.innerHTML=x',markup(p).split('class="shiny-bound-output">',1)[1].rsplit('</div>',1)[0]);page.wait_for_selector('.lvg-gd-panel svg')
        assert page.get_by_label('Display',exact=True).input_value()=='single'
        assert page.locator('.lvg-gd-panel header strong').inner_text()=='g: A <test> (n = 200)'
        assert page.locator('[data-edge="1:~:3"]').get_attribute('data-value')=='0.310'
        for kind in ['horizontal','vertical']:
            page.get_by_label('Layout',exact=True).select_option(kind);r=head_check(page);head_total+=r['count'];assert not r['bad'],(kind,r)
        page.get_by_label('Covariances',exact=True).uncheck();assert page.locator('[data-edge="1:~~:2"]').count()==0
        page.set_viewport_size({'width':375,'height':750});page.get_by_label('Display',exact=True).select_option('compare');page.get_by_label('Zoom',exact=True).select_option('70')
        assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth+1')
        # Mock the results modal's Bootstrap columns and tab visibility. The
        # expanded viewer must restore the settings when another tab is shown.
        page.set_viewport_size({'width':1500,'height':1000})
        page.evaluate("""(m)=>document.body.innerHTML='<div class="row" id="results-row"><div class="col-sm-4" id="settings">Settings</div><div class="col-sm-8"><div class="tab-pane active">'+m+'</div></div></div>'""", markup(cfa_fixture()))
        page.wait_for_selector('.lvg-gd-panel svg')
        toggle=page.get_by_role('button',name='Expand viewer')
        toggle.click();assert page.locator('#settings').evaluate("e=>getComputedStyle(e).display")=='none'
        page.locator('.tab-pane').evaluate("e=>e.classList.remove('active')")
        assert page.locator('#settings').evaluate("e=>getComputedStyle(e).display")!='none'
        page.locator('.tab-pane').evaluate("e=>e.classList.add('active')")
        page.get_by_role('button',name='Show analysis settings').click()
        assert page.locator('#settings').evaluate("e=>getComputedStyle(e).display")!='none'
        assert not errors,errors
        print(f'PASS: synthetic group/scale/stage/layout/drag/keyboard/SVG/mobile/expanded-view tests; {head_total} triangle inspections; no JavaScript errors.')
        browser.close()

if __name__=='__main__':main()
