#!/usr/bin/env python3
"""
Literary Clock Dashboard Server
Serves a live status dashboard over WiFi on port 8080
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import os
import json
from datetime import datetime
import socket

# Config
PORT = 8080
QUOTES_CSV = "/mnt/sd/quotes.csv"
WEATHER_CACHE = "/tmp/weather_cache.txt"
LITCLOCK_LOG = "/tmp/litclock.log"
REFRESH_FLAG = "/tmp/litclock_refresh"


def get_stats():
    """Gather all device and clock stats."""
    stats = {}

    # Time and date
    now = datetime.now()
    stats["time"] = now.strftime("%H:%M")
    stats["date"] = now.strftime("%A, %B %d %Y")

    # Battery
    try:
        with open("/sys/class/power_supply/mc13892_bat/capacity") as f:
            stats["battery"] = f.read().strip() + "%"
    except:
        stats["battery"] = "?"

    try:
        with open("/sys/class/power_supply/mc13892_bat/status") as f:
            stats["battery_status"] = f.read().strip()
    except:
        stats["battery_status"] = "Unknown"

    # Uptime
    try:
        result = subprocess.run(["uptime"], capture_output=True, text=True)
        uptime_raw = result.stdout.strip()
        # Extract just the "up X days/hours/mins" part
        uptime = uptime_raw.split("up ")[1].split(",")[0].strip()
        stats["uptime"] = uptime
    except:
        stats["uptime"] = "?"

    # WiFi signal
    try:
        with open("/proc/net/wireless") as f:
            for line in f:
                if "eth0" in line:
                    parts = line.split()
                    stats["wifi_signal"] = parts[2].replace(".", "") + " dBm"
                    break
                else:
                    stats["wifi_signal"] = "?"
    except:
        stats["wifi_signal"] = "?"

    # Quote count
    try:
        result = subprocess.run(["wc", "-l", QUOTES_CSV], capture_output=True, text=True)
        stats["quote_count"] = result.stdout.strip().split()[0]
    except:
        stats["quote_count"] = "?"

    # Weather
    try:
        with open(WEATHER_CACHE) as f:
            stats["weather"] = f.read().strip()
        mtime = os.path.getmtime(WEATHER_CACHE)
        stats["weather_updated"] = datetime.fromtimestamp(mtime).strftime("%H:%M")
    except:
        stats["weather"] = "No weather data"
        stats["weather_updated"] = "Never"

    # Current quote from log
    try:
        result = subprocess.run(
            ["grep", "Printing string", LITCLOCK_LOG],
            capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n")
        if lines and lines[-1]:
            last = lines[-1]
            # Extract text between first ' and ' @
            quote = last.split("Printing string '")[1].split("' @")[0]
            stats["current_quote"] = quote
        else:
            stats["current_quote"] = ""
    except:
        stats["current_quote"] = ""

    # Process status
    try:
        result = subprocess.run(["ps"], capture_output=True, text=True)
        ps_output = result.stdout
        stats["litclock_running"] = "litclock.sh" in ps_output and "grep" not in ps_output.split("litclock.sh")[0].split("\n")[-1]
        stats["touch_running"] = "touch_watcher" in ps_output
    except:
        stats["litclock_running"] = False
        stats["touch_running"] = False

    # Simplify process check
    try:
        result = subprocess.run(["ps"], capture_output=True, text=True)
        lines = result.stdout.split("\n")
        stats["litclock_running"] = any("litclock.sh" in l and "grep" not in l for l in lines)
        stats["touch_running"] = any("touch_watcher" in l and "grep" not in l for l in lines)
    except:
        pass

    return stats


def render_html(stats):
    """Render the dashboard HTML with current stats."""

    litclock_status = (
        '<span class="status-good">&#9679; Running</span>'
        if stats["litclock_running"]
        else '<span class="status-bad">&#9679; Stopped</span>'
    )
    touch_status = (
        '<span class="status-good">&#9679; Running</span>'
        if stats["touch_running"]
        else '<span class="status-bad">&#9679; Stopped</span>'
    )

    battery_int = int(stats["battery"].replace("%", "")) if "%" in stats["battery"] else 0
    if battery_int >= 75:
        batt_bar = '<span class="batt-full">&#9608;&#9608;&#9608;&#9608;</span>'
        batt_class = "status-good"
    elif battery_int >= 50:
        batt_bar = '<span class="batt-mid">&#9608;&#9608;&#9608;&#9617;</span>'
        batt_class = "status-warn"
    elif battery_int >= 25:
        batt_bar = '<span class="batt-low">&#9608;&#9608;&#9617;&#9617;</span>'
        batt_class = "status-warn"
    else:
        batt_bar = '<span class="batt-crit">&#9608;&#9617;&#9617;&#9617;</span>'
        batt_class = "status-bad"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="30">
<title>Literary Clock</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=IM+Fell+English:ital@0;1&family=IM+Fell+English+SC&display=swap');

  :root {{
    --ink: #1a1209;
    --paper: #f5f0e8;
    --aged: #e8dfc8;
    --accent: #8b3a1a;
    --faded: #9a8f7a;
    --rule: #c8b89a;
    --good: #2d6a2d;
    --warn: #8b6a1a;
    --bad: #8b3a1a;
  }}

  * {{ margin: 0; padding: 0; box-sizing: border-box; }}

  body {{
    background: var(--paper);
    color: var(--ink);
    font-family: 'IM Fell English', Georgia, serif;
    min-height: 100vh;
    padding: 2rem;
    background-image:
      radial-gradient(ellipse at 20% 20%, rgba(139,58,26,0.04) 0%, transparent 60%),
      radial-gradient(ellipse at 80% 80%, rgba(139,58,26,0.04) 0%, transparent 60%);
  }}

  .page-rule {{
    border: none;
    border-top: 2px solid var(--accent);
    border-bottom: 1px solid var(--rule);
    margin: 1rem 0;
    height: 4px;
  }}

  header {{ text-align: center; padding: 1.5rem 0 0.5rem; }}

  header h1 {{
    font-family: 'IM Fell English SC', Georgia, serif;
    font-size: 2.4rem;
    letter-spacing: 0.08em;
    color: var(--accent);
    font-weight: normal;
  }}

  header .dateline {{
    font-style: italic;
    color: var(--faded);
    font-size: 0.95rem;
    margin-top: 0.3rem;
    letter-spacing: 0.05em;
  }}

  .current-time {{
    text-align: center;
    font-size: 5rem;
    font-family: 'IM Fell English SC', Georgia, serif;
    color: var(--ink);
    line-height: 1;
    padding: 1rem 0 0.5rem;
    letter-spacing: 0.05em;
  }}

  .current-quote {{
    text-align: center;
    font-style: italic;
    font-size: 1.05rem;
    color: var(--faded);
    padding: 0.5rem 2rem 1rem;
    line-height: 1.6;
    min-height: 3rem;
    border-left: 3px solid var(--rule);
    border-right: 3px solid var(--rule);
    margin: 0 1rem;
  }}

  .weather-bar {{
    text-align: center;
    font-size: 1rem;
    color: var(--accent);
    letter-spacing: 0.1em;
    padding: 0.5rem 0;
    font-family: 'IM Fell English SC', serif;
  }}

  .grid {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.2rem;
    margin-top: 1.2rem;
  }}

  .card {{
    background: var(--aged);
    border: 1px solid var(--rule);
    padding: 1.2rem 1.4rem;
    position: relative;
  }}

  .card::before {{
    content: '';
    position: absolute;
    top: 3px; left: 3px; right: 3px; bottom: 3px;
    border: 1px solid var(--rule);
    pointer-events: none;
    opacity: 0.4;
  }}

  .card h2 {{
    font-family: 'IM Fell English SC', serif;
    font-size: 0.75rem;
    letter-spacing: 0.15em;
    color: var(--accent);
    font-weight: normal;
    margin-bottom: 0.8rem;
    text-transform: uppercase;
  }}

  .stat-row {{
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    padding: 0.35rem 0;
    border-bottom: 1px dotted var(--rule);
    font-size: 0.95rem;
    gap: 1rem;
  }}

  .stat-row:last-child {{ border-bottom: none; }}

  .stat-label {{
    color: var(--faded);
    font-style: italic;
    font-size: 0.88rem;
    white-space: nowrap;
  }}

  .stat-value {{ color: var(--ink); text-align: right; }}

  .status-good {{ color: var(--good); }}
  .status-warn {{ color: var(--warn); }}
  .status-bad  {{ color: var(--bad); }}
  .batt-full   {{ color: var(--good); font-family: monospace; }}
  .batt-mid    {{ color: var(--good); font-family: monospace; }}
  .batt-low    {{ color: var(--warn); font-family: monospace; }}
  .batt-crit   {{ color: var(--bad);  font-family: monospace; }}

  .btn {{
    display: inline-block;
    background: var(--accent);
    color: var(--paper);
    padding: 0.4rem 1.2rem;
    font-family: 'IM Fell English SC', serif;
    font-size: 0.85rem;
    letter-spacing: 0.08em;
    text-decoration: none;
    cursor: pointer;
  }}

  .btn:hover {{ background: var(--ink); }}

  .btn.secondary {{
    background: transparent;
    color: var(--accent);
    border: 1px solid var(--accent);
  }}

  .btn.secondary:hover {{ background: var(--aged); }}

  .refresh-note {{
    text-align: center;
    font-style: italic;
    color: var(--faded);
    font-size: 0.8rem;
    padding: 1rem 0 0.5rem;
  }}

  @media (max-width: 500px) {{
    .grid {{ grid-template-columns: 1fr; }}
    .current-time {{ font-size: 3.5rem; }}
    header h1 {{ font-size: 1.8rem; }}
    body {{ padding: 1rem; }}
  }}
</style>
</head>
<body>

<header>
  <h1>Literary Clock</h1>
  <div class="dateline">{stats['date']}</div>
</header>

<hr class="page-rule">

<div class="current-time">{stats['time']}</div>

<div class="current-quote">{stats['current_quote'] or 'No quote data available'}</div>

<div class="weather-bar">{stats['weather']}</div>

<hr class="page-rule">

<div class="grid">

  <div class="card">
    <h2>Device</h2>
    <div class="stat-row">
      <span class="stat-label">Battery</span>
      <span class="stat-value {batt_class}">{batt_bar} {stats['battery']} &mdash; {stats['battery_status']}</span>
    </div>
    <div class="stat-row">
      <span class="stat-label">Uptime</span>
      <span class="stat-value">{stats['uptime']}</span>
    </div>
    <div class="stat-row">
      <span class="stat-label">WiFi Signal</span>
      <span class="stat-value">{stats['wifi_signal']}</span>
    </div>
  </div>

  <div class="card">
    <h2>Clock</h2>
    <div class="stat-row">
      <span class="stat-label">litclock.sh</span>
      <span class="stat-value">{litclock_status}</span>
    </div>
    <div class="stat-row">
      <span class="stat-label">touch_watcher</span>
      <span class="stat-value">{touch_status}</span>
    </div>
    <div class="stat-row">
      <span class="stat-label">Quotes loaded</span>
      <span class="stat-value">{stats['quote_count']}</span>
    </div>
  </div>

  <div class="card">
    <h2>Weather</h2>
    <div class="stat-row">
      <span class="stat-label">Conditions</span>
      <span class="stat-value">{stats['weather']}</span>
    </div>
    <div class="stat-row">
      <span class="stat-label">Last fetched</span>
      <span class="stat-value">{stats['weather_updated']}</span>
    </div>
  </div>

  <div class="card">
    <h2>Actions</h2>
    <div class="stat-row">
      <span class="stat-label">Refresh quote</span>
      <span class="stat-value"><a href="/refresh" class="btn">Refresh</a></span>
    </div>
    <div class="stat-row">
      <span class="stat-label">Dashboard</span>
      <span class="stat-value"><a href="/" class="btn secondary">Reload</a></span>
    </div>
  </div>

</div>

<p class="refresh-note">Page auto-refreshes every 30 seconds &mdash; Last updated {datetime.now().strftime('%H:%M:%S')}</p>

</body>
</html>"""


class DashboardHandler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        # Suppress default request logging
        pass

    def do_GET(self):
        if self.path == "/refresh":
            # Trigger quote refresh
            open(REFRESH_FLAG, "w").close()
            # Redirect back to dashboard
            self.send_response(302)
            self.send_header("Location", "/")
            self.end_headers()

        elif self.path == "/api/status":
            # JSON endpoint for stats
            stats = get_stats()
            body = json.dumps(stats, indent=2).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", len(body))
            self.end_headers()
            self.wfile.write(body)

        else:
            # Serve dashboard
            stats = get_stats()
            body = render_html(stats).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", len(body))
            self.end_headers()
            self.wfile.write(body)


if __name__ == "__main__":

    # Get the local machine's IP address
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)

    print(f"Local IP address: {local_ip}")
    server = HTTPServer((local_ip, PORT), DashboardHandler)

    print(f"Literary Clock Dashboard running at http://{local_ip}:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Server stopped.")
        server.server_close()
