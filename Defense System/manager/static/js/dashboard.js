const API = "";

async function fetchJSON(path, options = {}) {
  const res = await fetch(`${API}${path}`, options);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || res.statusText);
  }
  return res.json();
}

function formatTime(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

function severityTag(severity) {
  const s = (severity || "medium").toLowerCase();
  return `<span class="tag tag-severity-${s}">${s}</span>`;
}

function statusTag(status, lastSeen) {
  const online = status === "online" && isRecentlySeen(lastSeen);
  return online
    ? '<span class="tag tag-online">online</span>'
    : '<span class="tag tag-offline">offline</span>';
}

function isRecentlySeen(lastSeen) {
  if (!lastSeen) return false;
  const diff = Date.now() - new Date(lastSeen).getTime();
  return diff < 120000;
}

function renderChart(byClass) {
  const el = document.getElementById("chart-bars");
  if (!byClass || byClass.length === 0) {
    el.innerHTML = '<p class="empty" style="padding:1rem">No alert data yet</p>';
    return;
  }
  const max = Math.max(...byClass.map((c) => c.count), 1);
  el.innerHTML = byClass
    .map(
      (c) => `
    <div class="bar-row">
      <span class="bar-label">${c.attack_class}</span>
      <div class="bar-track">
        <div class="bar-fill" style="width:${(c.count / max) * 100}%"></div>
      </div>
      <span class="bar-count">${c.count}</span>
    </div>`
    )
    .join("");
}

function renderAgents(agents) {
  const body = document.getElementById("agents-body");
  if (!agents.length) {
    body.innerHTML = '<tr><td colspan="5" class="empty">No agents registered yet</td></tr>';
    return;
  }
  body.innerHTML = agents
    .map(
      (a) => `
    <tr>
      <td>${a.hostname}</td>
      <td>${a.ip_address}</td>
      <td>${a.os_type}</td>
      <td>${statusTag(a.status, a.last_seen)}</td>
      <td>${formatTime(a.last_seen)}</td>
    </tr>`
    )
    .join("");
}

function renderAlerts(alerts) {
  const body = document.getElementById("alerts-body");
  if (!alerts.length) {
    body.innerHTML = '<tr><td colspan="7" class="empty">No alerts yet</td></tr>';
    return;
  }
  body.innerHTML = alerts
    .map(
      (a) => `
    <tr>
      <td>${formatTime(a.timestamp)}</td>
      <td><span class="tag tag-class">${a.attack_class}</span></td>
      <td>${a.source_ip || "—"}</td>
      <td>${a.dest_ip || "—"}</td>
      <td>${severityTag(a.severity)}</td>
      <td>${Math.round((a.confidence || 0) * 100)}%</td>
      <td>${a.description || "—"}</td>
    </tr>`
    )
    .join("");
}

async function loadDashboard() {
  const [summary, agents, alerts] = await Promise.all([
    fetchJSON("/api/dashboard/summary"),
    fetchJSON("/api/agents"),
    fetchJSON("/api/alerts?limit=50"),
  ]);

  document.getElementById("stat-agents-online").textContent = summary.agents_online;
  document.getElementById("stat-agents-total").textContent =
    `of ${summary.agents_total} registered`;
  document.getElementById("stat-alerts-total").textContent = summary.alerts_total;
  document.getElementById("stat-alerts-hour").textContent =
    `${summary.alerts_last_hour} in last hour`;

  const top = summary.alerts_by_class[0];
  document.getElementById("stat-top-threat").textContent = top ? top.attack_class : "—";

  const badge = document.getElementById("capture-badge");
  if (summary.capture_active) {
    badge.textContent = "Capture active";
    badge.className = "badge badge-active";
  } else {
    badge.textContent = "Capture idle";
    badge.className = "badge badge-muted";
  }

  renderChart(summary.alerts_by_class);
  renderAgents(agents);
  renderAlerts(alerts);
}

document.getElementById("btn-refresh").addEventListener("click", () => {
  loadDashboard().catch(console.error);
});

document.getElementById("btn-capture-start").addEventListener("click", async () => {
  await fetchJSON("/api/dashboard/capture/start", { method: "POST" });
  await loadDashboard();
});

document.getElementById("btn-capture-stop").addEventListener("click", async () => {
  await fetchJSON("/api/dashboard/capture/stop", { method: "POST" });
  await loadDashboard();
});

document.getElementById("btn-seed").addEventListener("click", async () => {
  await fetchJSON("/api/alerts/seed-demo", { method: "POST" });
  await loadDashboard();
});

loadDashboard().catch(console.error);
setInterval(() => loadDashboard().catch(console.error), 15000);
