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
        "name": "farmer_simplified_01_home_mobile.png",
        "url": "http://localhost:8080/#/",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 4.0,
    },
    {
        "name": "farmer_simplified_02_home_desktop.png",
        "url": "http://localhost:8080/#/",
        "width": 1400,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.0,
    },
    {
        "name": "farmer_simplified_03_worker_heat_mobile.png",
        "url": "http://localhost:8080/#/risk/worker-heat?farmId=11111111-1111-1111-1111-111111111111",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 5.0,
    },
    {
        "name": "farmer_simplified_04_crop_heat_mobile.png",
        "url": "http://localhost:8080/#/risk/crop-heat?farmId=11111111-1111-1111-1111-111111111111",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 5.0,
    },
    {
        "name": "farmer_simplified_05_farm_detail_mobile.png",
        "url": "http://localhost:8080/#/farms/11111111-1111-1111-1111-111111111111",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 5.0,
    },
    {
        "name": "farmer_simplified_06_farm_health_mobile.png",
        "url": "http://localhost:8080/#/farm-health/11111111-1111-1111-1111-111111111111",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 5.0,
    },
    {
        "name": "farmer_simplified_07_soil_intelligence_mobile.png",
        "url": "http://localhost:8080/#/soil-testing/11111111-1111-1111-1111-111111111111",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 5.0,
    },
    {
        "name": "farmer_simplified_08_earn_more_mobile.png",
        "url": "http://localhost:8080/#/extra-income?farmId=11111111-1111-1111-1111-111111111111",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 5.0,
    },
    {
        "name": "farmer_simplified_09_crop_doctor_mobile.png",
        "url": "http://localhost:8080/#/crop-doctor",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 4.0,
    },
    {
        "name": "farmer_simplified_10_government_help_mobile.png",
        "url": "http://localhost:8080/#/schemes",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 4.0,
    },
    {
        "name": "farmer_simplified_11_ask_rashkar_mobile.png",
        "url": "http://localhost:8080/#/advisory",
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

    # 3. Wait for load and rendering
    await asyncio.sleep(target["wait"])

    # 4. Capture screenshot
    await ws.send_json({
        "id": 30,
        "method": "Page.captureScreenshot",
        "params": {
            "format": "png",
            "quality": 90,
            "fromSurface": True,
        }
    })
    while True:
        m = await ws.receive_json()
        if m.get("id") == 30:
            data_b64 = m["result"]["data"]
            out_path = os.path.join(ARTIFACT_DIR, target["name"])
            with open(out_path, "wb") as f:
                f.write(base64.b64decode(data_b64))
            print(f"Saved: {out_path} ({len(data_b64)} bytes)")
            break

async def main():
    chrome_port = 9222
    user_data = r"C:\tmp\chrome_remote_profile_farmer"
    os.makedirs(user_data, exist_ok=True)
    
    cmd = [
        CHROME_BIN,
        f"--remote-debugging-port={chrome_port}",
        f"--user-data-dir={user_data}",
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--hide-scrollbars",
        "about:blank",
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2.0)

    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"http://127.0.0.1:{chrome_port}/json") as resp:
                targets = await resp.json()
                ws_url = targets[0]["webSocketDebuggerUrl"]

            async with session.ws_connect(ws_url, max_msg_size=100*1024*1024) as ws:
                await ws.send_json({"id": 1, "method": "Page.enable"})
                await ws.receive_json()
                
                for t in TARGETS:
                    await capture_target(ws, t)

    finally:
        proc.terminate()
        proc.wait()
        print("Chrome terminated cleanly.")

if __name__ == "__main__":
    asyncio.run(main())
