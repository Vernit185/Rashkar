import asyncio
import base64
import json
import os
import subprocess
import time
import aiohttp

CHROME_BIN = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
ARTIFACT_DIR = r"C:\Users\verni\.gemini\antigravity\brain\11d077b1-a769-4c58-a6eb-463255061f8a"
os.makedirs(ARTIFACT_DIR, exist_ok=True)

TARGETS = [
    {
        "name": "agrinova_01_home_desktop.png",
        "url": "http://localhost:8080/#/",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.0,
    },
    {
        "name": "agrinova_02_home_mobile.png",
        "url": "http://localhost:8080/#/",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 4.0,
    },
    {
        "name": "agrinova_03_worker_heat_desktop.png",
        "url": "http://localhost:8080/#/risk/worker-heat?farmId=11111111-1111-1111-1111-111111111111",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 5.0,
    },
    {
        "name": "agrinova_04_crop_heat_desktop.png",
        "url": "http://localhost:8080/#/risk/crop-heat?farmId=11111111-1111-1111-1111-111111111111",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 5.0,
    },
    {
        "name": "agrinova_05_crop_doctor_desktop.png",
        "url": "http://localhost:8080/#/crop-doctor",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.0,
    },
    {
        "name": "agrinova_06_soil_intelligence_desktop.png",
        "url": "http://localhost:8080/#/soil-testing",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.0,
    },
    {
        "name": "agrinova_07_extra_income_desktop.png",
        "url": "http://localhost:8080/#/extra-income?farmId=11111111-1111-1111-1111-111111111111",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 5.0,
    },
    {
        "name": "agrinova_08_soil_report_desktop.png",
        "url": "http://localhost:8080/#/soil-testing/11111111-1111-1111-1111-111111111111",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 5.0,
    },
    {
        "name": "agrinova_09_crop_doctor_mobile.png",
        "url": "http://localhost:8080/#/crop-doctor",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 4.0,
    },
    {
        "name": "agrinova_10_soil_report_mobile.png",
        "url": "http://localhost:8080/#/soil-testing/11111111-1111-1111-1111-111111111111",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 5.0,
    },
    {
        "name": "agrinova_11_extra_income_mobile.png",
        "url": "http://localhost:8080/#/extra-income?farmId=11111111-1111-1111-1111-111111111111",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 5.0,
    },
]

async def capture_target(ws, target):
    print(f"Capturing {target['name']} at {target['url']} ({target['width']}x{target['height']})...")
    
    # 1. Metrics override
    await ws.send_json({
        "id": 10,
        "method": "Emulation.setDeviceMetricsOverride",
        "params": {
            "width": target["width"],
            "height": target["height"],
            "deviceScaleFactor": target["device_scale"],
            "mobile": target["mobile"],
        }
    })
    while True:
        m = await ws.receive_json()
        if m.get("id") == 10:
            break

    # 2. Navigate
    await ws.send_json({
        "id": 20,
        "method": "Page.navigate",
        "params": {"url": target["url"]}
    })
    while True:
        m = await ws.receive_json()
        if m.get("id") == 20:
            break

    # 3. Wait for Flutter Web rendering
    await asyncio.sleep(target.get("wait", 4.0))

    # 4. Capture screenshot
    await ws.send_json({
        "id": 30,
        "method": "Page.captureScreenshot",
        "params": {"format": "png"}
    })
    while True:
        m = await ws.receive_json()
        if m.get("id") == 30:
            img_b64 = m["result"]["data"]
            break

    data = base64.b64decode(img_b64)
    out_path = os.path.join(ARTIFACT_DIR, target["name"])
    with open(out_path, "wb") as f:
        f.write(data)
    print(f"  ✓ Saved to {out_path} ({len(data)} bytes)")

async def main():
    chrome_proc = subprocess.Popen([
        CHROME_BIN,
        "--headless=new",
        "--remote-debugging-port=9222",
        "--disable-gpu",
        "--no-sandbox",
        "--disable-extensions",
        "--hide-scrollbars",
    ])
    
    try:
        # Wait for Chrome CDP port to open
        ws_url = None
        for _ in range(20):
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get("http://localhost:9222/json") as r:
                        tabs = await r.json()
                        if tabs and len(tabs) > 0:
                            ws_url = tabs[0]["webSocketDebuggerUrl"]
                            break
            except Exception:
                pass
            await asyncio.sleep(0.5)

        if not ws_url:
            raise RuntimeError("Could not connect to Chrome DevTools Protocol at port 9222")

        print(f"Connected to Chrome: {ws_url}")
        async with aiohttp.ClientSession() as session:
            async with session.ws_connect(ws_url) as ws:
                # Enable Page
                await ws.send_json({"id": 1, "method": "Page.enable"})
                while True:
                    m = await ws.receive_json()
                    if m.get("id") == 1:
                        break

                for target in TARGETS:
                    await capture_target(ws, target)
                    await asyncio.sleep(1.0)
                    
        print("\nAll AgriNova screenshots captured successfully!")
    finally:
        chrome_proc.terminate()
        try:
            chrome_proc.wait(timeout=3)
        except Exception:
            chrome_proc.kill()

if __name__ == "__main__":
    asyncio.run(main())
