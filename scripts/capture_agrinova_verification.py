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
        "name": "agrinova_home_desktop_1440.png",
        "url": "http://localhost:8080/#/",
        "width": 1440,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
    {
        "name": "agrinova_home_mobile_390.png",
        "url": "http://localhost:8080/#/",
        "width": 390,
        "height": 844,
        "device_scale": 2.0,
        "mobile": True,
        "wait": 4.5,
    },
    {
        "name": "agrinova_worker_heat_desktop.png",
        "url": "http://localhost:8080/#/risk",
        "width": 1440,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
    {
        "name": "agrinova_crop_heat_desktop.png",
        "url": "http://localhost:8080/#/risk/crop-heat",
        "width": 1440,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
    {
        "name": "agrinova_soil_report_desktop.png",
        "url": "http://localhost:8080/#/soil-testing/11111111-1111-1111-1111-111111111111",
        "width": 1440,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
    {
        "name": "agrinova_weather_report_desktop.png",
        "url": "http://localhost:8080/#/weather/11111111-1111-1111-1111-111111111111",
        "width": 1440,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
    {
        "name": "agrinova_farm_detail_desktop.png",
        "url": "http://localhost:8080/#/farms/11111111-1111-1111-1111-111111111111",
        "width": 1440,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
    {
        "name": "agrinova_crop_doctor_desktop.png",
        "url": "http://localhost:8080/#/crop-doctor",
        "width": 1440,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
    {
        "name": "agrinova_extra_income_desktop.png",
        "url": "http://localhost:8080/#/extra-income",
        "width": 1440,
        "height": 900,
        "device_scale": 1.0,
        "mobile": False,
        "wait": 4.5,
    },
]

async def send_cmd(ws, msg_id, method, params=None):
    payload = {"id": msg_id, "method": method}
    if params:
        payload["params"] = params
    await ws.send_str(json.dumps(payload))
    while True:
        resp = await ws.receive()
        if resp.type == aiohttp.WSMsgType.TEXT:
            data = json.loads(resp.data)
            if data.get("id") == msg_id:
                return data

async def capture_target(ws, target):
    print(f"Capturing {target['name']} at {target['url']} ({target['width']}x{target['height']})...")
    
    await send_cmd(ws, 1, "Emulation.setDeviceMetricsOverride", {
        "width": target["width"],
        "height": target["height"],
        "deviceScaleFactor": target.get("device_scale", 1.0),
        "mobile": target.get("mobile", False),
    })

    await send_cmd(ws, 2, "Page.navigate", {"url": target["url"]})
    await asyncio.sleep(target.get("wait", 4.0))

    resp = await send_cmd(ws, 3, "Page.captureScreenshot", {"format": "png"})
    img_data = resp["result"]["data"]
    raw = base64.b64decode(img_data)
    
    out_path = os.path.join(ARTIFACT_DIR, target["name"])
    with open(out_path, "wb") as f:
        f.write(raw)
    print(f"  -> Saved {out_path} ({len(raw)} bytes)")

async def main():
    debug_port = 9223
    user_data_dir = os.path.join(os.environ.get("TEMP", "C:\\Temp"), "chrome_dev_capture_agrinova")
    
    cmd = [
        CHROME_BIN,
        f"--remote-debugging-port={debug_port}",
        f"--user-data-dir={user_data_dir}",
        "--headless=new",
        "--disable-gpu",
        "--no-first-run",
        "--no-default-browser-check",
        "about:blank",
    ]
    proc = subprocess.Popen(cmd)
    time.sleep(2.0)

    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"http://127.0.0.1:{debug_port}/json") as resp:
                tabs = await resp.json()
                ws_url = tabs[0]["webSocketDebuggerUrl"]

            async with session.ws_connect(ws_url, max_msg_size=100 * 1024 * 1024) as ws:
                await send_cmd(ws, 100, "Page.enable")
                for t in TARGETS:
                    await capture_target(ws, t)
    finally:
        proc.terminate()
        proc.wait()

if __name__ == "__main__":
    asyncio.run(main())
