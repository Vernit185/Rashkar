import asyncio
import os
from playwright.async_api import async_playwright

ARTIFACT_DIR = r"C:\Users\verni\.gemini\antigravity\brain\11d077b1-a769-4c58-a6eb-463255061f8a"

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        # Mock Mumbai location: 19.0760° N, 72.8777° E
        context = await browser.new_context(
            viewport={"width": 430, "height": 932},
            permissions=["geolocation"],
            geolocation={"latitude": 19.0760, "longitude": 72.8777, "accuracy": 15.0},
        )
        page = await context.new_page()

        print("Navigating to http://localhost:8080/#/onboarding...")
        await page.goto("http://localhost:8080/#/onboarding", wait_until="networkidle")
        await asyncio.sleep(3.5)

        # Step 1: Name input
        print("Step 1: Entering name...")
        await page.mouse.click(200, 285)
        await page.keyboard.type("Ramesh Patil")
        await asyncio.sleep(0.5)

        # Continue from Step 1 (y=460)
        await page.mouse.click(215, 460)
        await asyncio.sleep(1.5)

        # Step 2: Age -> Continue (y=460)
        await page.mouse.click(215, 460)
        await asyncio.sleep(2.0)

        # Step 3: Location
        print("Clicking 'Use My Location' at (125, 275)...")
        await page.mouse.click(125, 275)
        await asyncio.sleep(3.0)
        await page.screenshot(path=os.path.join(ARTIFACT_DIR, "step3_live_gps_mumbai.png"))

        # Tap 4 corners on map
        print("Tapping 4 corners on map...")
        await page.mouse.click(150, 400)
        await asyncio.sleep(0.6)
        await page.mouse.click(280, 400)
        await asyncio.sleep(0.6)
        await page.mouse.click(280, 500)
        await asyncio.sleep(0.6)
        await page.mouse.click(150, 500)
        await asyncio.sleep(1.5)
        await page.screenshot(path=os.path.join(ARTIFACT_DIR, "step3_polygon_and_live_area.png"))

        # Click Continue on Step 3 (y=715)
        print("Clicking Continue to Step 4...")
        await page.mouse.click(215, 715)
        await asyncio.sleep(2.0)
        await page.screenshot(path=os.path.join(ARTIFACT_DIR, "step4_auto_calculated_area.png"))

        # Click Continue on Step 4 (y=715 or around there)
        print("Clicking Continue to Step 5 (Crop)...")
        await page.mouse.click(215, 715)
        await asyncio.sleep(2.0)
        await page.screenshot(path=os.path.join(ARTIFACT_DIR, "step5_crop_selection.png"))

        print("Verification script completed successfully!")
        await browser.close()

if __name__ == "__main__":
    asyncio.run(run())
