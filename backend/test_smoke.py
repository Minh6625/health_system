import urllib.request, json
import sys, os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

data = json.dumps({
    "db_device_id": 1,
    "user_id": 1,
    "event_type": "fall_detected",
    "severity": "critical",
    "timestamp": "2026-03-24T12:00:00Z",
    "metadata": {"variant": "fall_1", "confidence": 0.99}
}).encode()

for path in ["/mobile/telemetry/alert", "/api/v1/mobile/telemetry/alert"]:
    url = f"http://localhost:8000{path}"
    try:
        req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read().decode()
            print(f"SUCCESS {url}:", resp.status)
            try:
                print(json.dumps(json.loads(body), indent=2))
            except:
                print(body)
            break
    except Exception as e:
        pass
