"""Synthetic browser-only test of signed differences and saved difference views.
Run from the package root: python tests/manual/advanced_difference_browser.py
Requires Playwright and Chromium; not an integration test with real Shiny/R.
"""
from advanced_diagram_browser import JS, cfa_fixture, markup, head_check
from playwright.sync_api import sync_playwright
import os, shutil, tempfile
from pathlib import Path
import xml.etree.ElementTree as ET

with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path=os.environ.get('CHROMIUM') or shutil.which('chromium'),headless=True,args=['--no-sandbox'])
    page=browser.new_page(viewport={'width':1600,'height':1100},accept_downloads=True)
    errors=[]; page.on('pageerror',lambda e:errors.append(str(e)))
    payload=cfa_fixture(); payload.update(stateInput='test-view',viewToken='delta-1')
    # A missing parameter row in group 2 is not interpreted as a zero.
    payload['rows']=[r for r in payload['rows'] if not (r['group']==2 and r['from']==2 and r['to']==8 and r['op']=='=~')]
    # A pair for which subtracting rounded values would yield the wrong answer.
    for r in payload['rows']:
        if r['from']==1 and r['to']==5 and r['op']=='=~':
            r['raw']={1:.73049,2:.73051,3:.88}[r['group']]
    page.set_content('<html><body>'+markup(payload)+'<script>window.events=[];window.Shiny={setInputValue:(name,value,opt)=>events.push(JSON.parse(value))};</script><script>'+JS+'</script></body></html>')
    page.wait_for_selector('.lvg-gd-panel svg')
    page.get_by_label('Display',exact=True).select_option('difference')
    panels=page.locator('.lvg-gd-panel')
    assert panels.count()==3
    delta=page.locator('.lvg-gd-panel[data-difference="true"]')
    def value(key): return delta.locator(f'[data-edge="{key}"]').get_attribute('data-value')
    assert value('1:=~:4')=='+0.080'
    assert value('1:=~:3')=='0.000'
    assert value('1:=~:5')=='0.000'
    assert value('2:=~:8')=='NA'
    page.get_by_label('Decimals',exact=True).select_option('4')
    assert value('1:=~:5')=='0.0000'
    page.get_by_label('Coefficients',exact=True).select_option('std')
    assert value('1:=~:4')=='NA'
    assert value('1:=~:3')=='-0.0250'
    page.get_by_label('Group',exact=True).select_option('2')
    page.get_by_label('Second group',exact=True).select_option('1')
    assert value('1:=~:3')=='+0.0250'
    assert '1 − 2' in delta.locator('header').inner_text()
    node=delta.locator('[data-node="1"]'); before=float(node.locator('ellipse').get_attribute('cx'))
    node.focus();page.keyboard.press('Shift+ArrowRight')
    moved=float(delta.locator('[data-node="1"] ellipse').get_attribute('cx'))
    xs=page.locator('[data-node="1"] ellipse').evaluate_all('(x)=>x.map(n=>Number(n.getAttribute("cx")))')
    assert moved==before+24 and xs==[moved]*3,xs
    checks=head_check(page);assert not checks['bad'],checks
    with tempfile.TemporaryDirectory() as t:
        with page.expect_download() as dl: delta.get_by_role('button',name='Download SVG').click()
        download=dl.value; assert 'difference-' in download.suggested_filename
        f=Path(t)/'delta.svg';download.save_as(f)
        svg=ET.parse(f).getroot(); desc=' '.join(svg.itertext())
        assert 'Difference' in desc and 'Descriptive difference only' in desc and '+0.0250' in desc,desc
    v=page.evaluate('events.at(-1).view'); assert v['mode']=='difference' and v['group']=='2' and v['other']=='1'
    payload.update(viewToken='delta-2',restoredView=v)
    page.evaluate('(m)=>document.querySelector("#diagram-output").outerHTML=m',markup(payload))
    page.wait_for_selector('.lvg-gd-panel[data-difference="true"] svg')
    assert panels.count()==3 and value('1:=~:3')=='+0.0250'
    assert page.evaluate('events.at(-1).view')==v
    assert not errors, errors
    print(f'PASS: difference arithmetic before rounding, signed zero, missing values/rows, reversed direction, shared layout, SVG and restored view; {checks["count"]} arrowhead inspections; no JS errors.')
    browser.close()
