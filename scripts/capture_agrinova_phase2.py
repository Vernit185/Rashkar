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
        "name": "phase2_01_splash_desktop.png",
        "url": "http://localhost:8080/#/splash",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 2.0,
    },
    {
        "name": "phase2_02_onboarding_step1_desktop.png",
        "url": "http://localhost:8080/#/onboarding",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 3.5,
    },
    {
        "name": "phase2_03_onboarding_step1_mobile.png",
        "url": "http://localhost:8080/#/onboarding",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 3.5,
    },
    {
        "name": "phase2_04_weather_report_desktop.png",
        "url": "http://localhost:8080/#/weather/11111111-1111-1111-1111-111111111111",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
    {
        "name": "phase2_05_satellite_vegetation_desktop.png",
        "url": "http://localhost:8080/#/farms/11111111-1111-1111-1111-111111111111/vegetation",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
    {
        "name": "phase2_06_advisory_desktop.png",
        "url": "http://localhost:8080/#/advisory",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.0,
    },
    {
        "name": "phase2_07_weather_report_mobile.png",
        "url": "http://localhost:8080/#/weather/11111111-1111-1111-1111-111111111111",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 4.0,
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
        "--remote-debugging-port=9225",
        "--disable-gpu",
        "--no-sandbox",
        "--disable-extensions",
        "--hide-scrollbars",
    ])
    
    try:
        ws_url = None
        for _ in range(25):
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get("http://localhost:9225/json") as r:
                        tabs = await r.json()
                        if tabs and len(tabs) > 0:
                            ws_url = tabs[0]["webSocketDebuggerUrl"]
                            break
            except Exception:
                pass
            await asyncio.sleep(0.5)

        if not ws_url:
            print("Failed to get Chrome tab WebSocket URL!")
            return

        async with aiohttp.ClientSession() as session:
            async with session.ws_connect(ws_url, max_msg_size=50 * 1024 * 1024) as ws:
                await ws.send_json({"id": 1, "method": "Page.enable"})
                while True:
                    m = await ws.receive_json()
                    if m.get("id") == 1:
                        break

                for t in TARGETS:
                    await capture_target(ws, t)

    finally:
        chrome_proc.terminate()
        try:
            chrome_proc.wait(timeout=3)
        except Exception:
            chrome_proc.kill()

if __name__ == "__main__":
    asyncio.run(main())
