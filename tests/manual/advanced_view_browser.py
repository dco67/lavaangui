"""Browser-only saved-view roundtrip with a simulated Shiny input bridge.
Run: python tests/manual/advanced_view_browser.py
Requires playwright + Chromium. Does not test actual R/Shiny transport.
"""
from advanced_diagram_browser import JS, cfa_fixture, markup, head_check
from playwright.sync_api import sync_playwright
import os, shutil

with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path=os.environ.get('CHROMIUM') or shutil.which('chromium'),headless=True,args=['--no-sandbox'])
    page=browser.new_page(viewport={'width':1400,'height':1000})
    errors=[]; page.on('pageerror',lambda e:errors.append(str(e)))
    payload=cfa_fixture();payload.update(stateInput='test-view',viewToken='1',ordinal=True)
    page.set_content('<html><body>'+markup(payload)+'<script>window.events=[];window.Shiny={setInputValue:(name,value,opt)=>events.push({name, ...JSON.parse(value)})};</script><script>'+JS+'</script></body></html>')
    page.wait_for_selector('.lvg-gd-panel svg')
    page.get_by_label('Display',exact=True).select_option('compare')
    page.get_by_label('Group',exact=True).select_option('2')
    page.get_by_label('Second group',exact=True).select_option('3')
    page.get_by_label('Coefficients',exact=True).select_option('std')
    page.get_by_label('Zoom',exact=True).select_option('125')
    page.get_by_label('Decimals',exact=True).select_option('4')
    page.get_by_label('Covariances',exact=True).uncheck()
    page.get_by_label('Variances',exact=True).check()
    page.get_by_label('Layout',exact=True).select_option('vertical')
    node=page.locator('.lvg-gd-panel').first.locator('[data-node="1"]')
    before=float(node.locator('ellipse').get_attribute('cx'))
    node.focus();page.keyboard.press('Shift+ArrowRight')
    moved=float(node.locator('ellipse').get_attribute('cx')); assert moved==before+24
    ev=page.evaluate('events.at(-1)'); v=ev['view']
    assert ev['token']=='1' and ev['name']=='test-view' and v['stage']=='Configural'
    assert (v['group'],v['other'],v['mode'],v['scale'],v['kind'],v['zoom'],v['digits'],v['variances'],v['covariances'])==('2','3','compare','std','vertical',125,4,True,False)
    assert v['positions'][0]['x']==moved
    # Simulate fresh completed analysis and server-provided validated recipe.
    payload.update(viewToken='2',restoredView=v)
    page.evaluate('(html)=>document.querySelector("#diagram-output").outerHTML=html',markup(payload))
    page.wait_for_selector('.lvg-gd-panel svg')
    assert page.get_by_label('Group',exact=True).input_value()=='2'
    assert page.get_by_label('Second group',exact=True).input_value()=='3'
    assert page.get_by_label('Layout',exact=True).input_value()=='vertical'
    assert page.get_by_label('Coefficients',exact=True).input_value()=='std'
    assert page.get_by_label('Zoom',exact=True).input_value()=='125'
    assert page.get_by_label('Decimals',exact=True).input_value()=='4'
    assert page.get_by_label('Variances',exact=True).is_checked()
    assert not page.get_by_label('Covariances',exact=True).is_checked()
    xs=page.locator('[data-node="1"] ellipse').evaluate_all('(x)=>x.map(n=>Number(n.getAttribute("cx")))')
    assert xs==[moved,moved],xs
    restored=page.evaluate('events.at(-1)');assert restored['token']=='2' and restored['view']==v,(restored,v)
    check=head_check(page);assert not check['bad'],check
    # An unrelated analysis token without a recipe must not inherit a stale layout.
    payload.pop('restoredView');payload['viewToken']='3'
    page.evaluate('(html)=>document.querySelector("#diagram-output").outerHTML=html',markup(payload));page.wait_for_selector('.lvg-gd-panel svg')
    assert page.get_by_label('Display',exact=True).input_value()=='single'
    assert page.get_by_label('Zoom',exact=True).input_value()=='100'
    # A malformed browser recipe falls back to default (server also validates).
    v['positions'][0]['x']='bad';payload.update(viewToken='4',restoredView=v)
    page.evaluate('(html)=>document.querySelector("#diagram-output").outerHTML=html',markup(payload));page.wait_for_selector('.lvg-gd-panel svg')
    assert page.get_by_label('Display',exact=True).input_value()=='single'
    assert not errors,errors
    print(f'PASS: emitted and restored layout, display options, token isolation, invalid recipe fallback; {check["count"]} restored arrowhead inspections; no JS errors.')
    browser.close()
