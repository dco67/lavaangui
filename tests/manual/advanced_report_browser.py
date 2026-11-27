"""Offline report renderer check, with synthetic diagram payload and no Shiny.
Optional: pass a real exported HTML report to check that file instead.
Requires playwright and Chromium, like the earlier browser tests.
"""
from pathlib import Path
import os
import shutil
import sys
import tempfile
from playwright.sync_api import sync_playwright
from advanced_diagram_browser import JS, markup, path_fixture, head_check

with tempfile.TemporaryDirectory() as tmp, sync_playwright() as pw:
    chromium = os.environ.get('CHROMIUM') or shutil.which('chromium') or shutil.which('chromium-browser')
    browser = pw.chromium.launch(executable_path=chromium, headless=True, args=['--no-sandbox'])
    page = browser.new_page(viewport={'width': 1500, 'height': 1000}, accept_downloads=True)
    errors, network = [], []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('request', lambda req: network.append(req.url) if req.url.startswith(('http:', 'https:')) else None)
    page.route('http**://**/*', lambda route: route.abort())
    actual = len(sys.argv) > 1
    if actual:
        path = Path(sys.argv[1]).resolve(strict=True)
    else:
        # Match the report's offline data attribute + inline package renderer.
        p = path_fixture()
        p['restoredView'] = {'stage': p['model'], 'group': p['groups'][0]['label'], 'other': p['groups'][1]['label'],
            'mode':'difference','kind':'horizontal','scale':'std','digits':4,'zoom':85,'covariances':True,'variances':False,'wide':False,
            'positions':[{'label':n['label'],'x':140+100*i,'y':150+40*i} for i,n in enumerate(p['nodes'])]}
        path = Path(tmp) / 'offline-report-fixture.html'
        path.write_text('<!doctype html><meta charset="utf-8"><title>Offline report fixture</title><h1>Analysis report</h1>'+markup(p)+'<script>'+JS+'</script>',encoding='utf-8')
    page.set_content(path.read_text(encoding="utf-8"))
    page.wait_for_selector('.lvg-gd-panel svg')
    assert page.evaluate('typeof window.Shiny === "undefined"'), 'Fixture depends on Shiny'
    if not actual:
        assert page.locator('.lvg-gd-panel svg').count() == 3, 'Restored comparison mode missing'
        assert page.get_by_label('Display', exact=True).input_value() == 'difference'
        assert page.get_by_label('Coefficients', exact=True).input_value() == 'std'
    page.get_by_label('Display', exact=True).select_option('compare')
    assert page.locator('.lvg-gd-panel svg').count() == 2
    with page.expect_download() as event:
        page.get_by_role('button', name='Download SVG').first.click()
    target = Path(tmp) / 'export.svg'; event.value.save_as(target)
    assert '<svg' in target.read_text(encoding='utf-8')
    assert not errors, errors
    assert not network, network
    browser.close()
    print('PASS: offline diagram renderer and SVG download, no Shiny, no external requests or JavaScript errors' + (' (actual report)' if actual else ' (synthetic report shell)'))
