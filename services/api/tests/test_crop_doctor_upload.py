import asyncio
import time
import httpx
import pytest
from cropnet.services.api.app.main import app
from cropnet.services.api.app.services.crop_doctor import inference


@pytest.mark.asyncio
async def test_slow_diagnosis_does_not_block_other_browser_requests(monkeypatch):
    state = {'done': False}

    def predict(_):
        time.sleep(0.5)
        state['done'] = True
        return {'label': 'Tomato___healthy', 'confidence': 91.0}

    monkeypatch.setattr(inference, 'get_prediction', predict)
    monkeypatch.setattr(inference, 'model_status', lambda: {'loaded': True})
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url='http://test') as client:
        async def upload():
            response = await client.post('/api/v1/crop-doctor/predict', files={'file': ('leaf.png', b'test-image', 'image/png')})
            assert response.status_code == 200

        async def other_browser_request():
            await asyncio.sleep(0.02)
            response = await client.get('/api/v1/crop-doctor/status')
            assert response.status_code == 200
            assert not state['done'], 'Diagnosis blocked the API event loop'

        await asyncio.gather(upload(), other_browser_request())
