#!/bin/bash
# init.sh - Custom data script for VMSS App Tier VMs
# Runs as root on first boot via Azure cloud-init

set -euo pipefail
exec > /var/log/init-script.log 2>&1

# --- System Update & Install ---
apt-get update -y
apt-get install -y nginx curl

# --- Enable and Start Nginx ---
systemctl enable nginx
systemctl start nginx

# --- Write the Webpage ---
cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Fortress VNet | Secure 3-Tier Azure Infrastructure</title>
  <meta name="description" content="Production-grade 3-Tier Azure Virtual Network architecture powered by Terraform." />
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700;900&display=swap" rel="stylesheet" />
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --accent: #6366f1;
      --accent-2: #8b5cf6;
      --green: #10b981;
      --surface: rgba(255,255,255,0.06);
      --border: rgba(255,255,255,0.12);
    }

    body {
      font-family: 'Inter', sans-serif;
      background: #060818;
      color: #e2e8f0;
      min-height: 100vh;
      overflow-x: hidden;
    }

    /* Animated gradient background */
    body::before {
      content: '';
      position: fixed;
      inset: 0;
      background:
        radial-gradient(ellipse 80% 50% at 20% 20%, rgba(99,102,241,0.18) 0%, transparent 60%),
        radial-gradient(ellipse 60% 50% at 80% 80%, rgba(139,92,246,0.14) 0%, transparent 60%),
        radial-gradient(ellipse 50% 40% at 50% 50%, rgba(16,185,129,0.07) 0%, transparent 70%);
      pointer-events: none;
      z-index: 0;
    }

    /* Grid dots overlay */
    body::after {
      content: '';
      position: fixed;
      inset: 0;
      background-image: radial-gradient(rgba(255,255,255,0.035) 1px, transparent 1px);
      background-size: 40px 40px;
      pointer-events: none;
      z-index: 0;
    }

    .container {
      position: relative;
      z-index: 1;
      max-width: 1100px;
      margin: 0 auto;
      padding: 0 24px;
    }

    /* ---- NAV ---- */
    nav {
      position: sticky;
      top: 0;
      z-index: 100;
      backdrop-filter: blur(20px);
      border-bottom: 1px solid var(--border);
      background: rgba(6,8,24,0.75);
    }
    .nav-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 18px 24px;
      max-width: 1100px;
      margin: 0 auto;
    }
    .logo {
      font-size: 1.15rem;
      font-weight: 700;
      letter-spacing: -0.5px;
      background: linear-gradient(135deg, #6366f1, #10b981);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      font-size: 0.78rem;
      font-weight: 600;
      color: var(--green);
      border: 1px solid rgba(16,185,129,0.3);
      border-radius: 999px;
      padding: 5px 14px;
      background: rgba(16,185,129,0.08);
    }
    .dot {
      width: 7px; height: 7px;
      border-radius: 50%;
      background: var(--green);
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%,100% { opacity: 1; transform: scale(1); }
      50%      { opacity: 0.4; transform: scale(0.7); }
    }

    /* ---- HERO ---- */
    .hero {
      text-align: center;
      padding: 110px 24px 80px;
    }
    .eyebrow {
      display: inline-block;
      font-size: 0.75rem;
      font-weight: 600;
      letter-spacing: 2px;
      text-transform: uppercase;
      color: var(--accent);
      border: 1px solid rgba(99,102,241,0.35);
      border-radius: 999px;
      padding: 5px 16px;
      margin-bottom: 28px;
      background: rgba(99,102,241,0.08);
      animation: fadeSlideDown 0.8s ease both;
    }
    .hero h1 {
      font-size: clamp(2.5rem, 6vw, 4.5rem);
      font-weight: 900;
      letter-spacing: -2px;
      line-height: 1.08;
      margin-bottom: 24px;
      animation: fadeSlideDown 0.9s ease both;
    }
    .hero h1 span {
      background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 40%, #10b981 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .hero p {
      max-width: 580px;
      margin: 0 auto 40px;
      font-size: 1.05rem;
      line-height: 1.75;
      color: #94a3b8;
      animation: fadeSlideDown 1s ease both;
    }
    .hero-actions {
      display: flex;
      gap: 14px;
      justify-content: center;
      flex-wrap: wrap;
      animation: fadeSlideDown 1.1s ease both;
    }
    .btn-primary {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 13px 28px;
      border-radius: 10px;
      background: linear-gradient(135deg, var(--accent), var(--accent-2));
      color: #fff;
      font-size: 0.9rem;
      font-weight: 600;
      text-decoration: none;
      border: none;
      cursor: pointer;
      transition: transform 0.2s, box-shadow 0.2s;
      box-shadow: 0 4px 24px rgba(99,102,241,0.35);
    }
    .btn-primary:hover { transform: translateY(-2px); box-shadow: 0 8px 32px rgba(99,102,241,0.5); }
    .btn-secondary {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 13px 28px;
      border-radius: 10px;
      color: #e2e8f0;
      font-size: 0.9rem;
      font-weight: 600;
      text-decoration: none;
      border: 1px solid var(--border);
      background: var(--surface);
      transition: background 0.2s, border-color 0.2s;
      cursor: pointer;
    }
    .btn-secondary:hover { background: rgba(255,255,255,0.1); border-color: rgba(255,255,255,0.2); }

    @keyframes fadeSlideDown {
      from { opacity: 0; transform: translateY(-20px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    /* ---- STATS ---- */
    .stats-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      margin-bottom: 80px;
    }
    .stat-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 24px;
      text-align: center;
      backdrop-filter: blur(10px);
      transition: transform 0.2s, border-color 0.2s;
    }
    .stat-card:hover { transform: translateY(-3px); border-color: rgba(99,102,241,0.35); }
    .stat-value {
      font-size: 2rem;
      font-weight: 800;
      background: linear-gradient(135deg, var(--accent), var(--green));
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .stat-label { font-size: 0.78rem; color: #64748b; margin-top: 4px; text-transform: uppercase; letter-spacing: 1px; }

    /* ---- SECTION HEADERS ---- */
    .section-header {
      text-align: center;
      margin-bottom: 48px;
    }
    .section-header h2 {
      font-size: 1.9rem;
      font-weight: 800;
      letter-spacing: -0.8px;
      margin-bottom: 10px;
    }
    .section-header p { color: #64748b; font-size: 0.95rem; }

    /* ---- TIER CARDS ---- */
    .tier-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 20px;
      margin-bottom: 80px;
    }
    .tier-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 28px;
      backdrop-filter: blur(10px);
      transition: transform 0.25s, box-shadow 0.25s, border-color 0.25s;
      position: relative;
      overflow: hidden;
    }
    .tier-card::before {
      content: '';
      position: absolute;
      top: 0; left: 0; right: 0;
      height: 3px;
      border-radius: 18px 18px 0 0;
    }
    .tier-card.tier-1::before { background: linear-gradient(90deg, #6366f1, #8b5cf6); }
    .tier-card.tier-2::before { background: linear-gradient(90deg, #10b981, #06b6d4); }
    .tier-card.tier-3::before { background: linear-gradient(90deg, #f59e0b, #ef4444); }
    .tier-card:hover { transform: translateY(-5px); box-shadow: 0 16px 48px rgba(0,0,0,0.3); border-color: rgba(255,255,255,0.2); }
    .tier-icon {
      font-size: 2rem;
      margin-bottom: 14px;
    }
    .tier-title { font-size: 1.1rem; font-weight: 700; margin-bottom: 8px; }
    .tier-sub  { font-size: 0.8rem; color: #64748b; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 16px; font-weight: 600; }
    .tier-list { list-style: none; }
    .tier-list li {
      font-size: 0.875rem;
      color: #94a3b8;
      padding: 6px 0;
      border-bottom: 1px solid rgba(255,255,255,0.04);
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .tier-list li:last-child { border-bottom: none; }
    .tier-list li::before { content: '→'; color: var(--accent); font-size: 0.75rem; flex-shrink: 0; }

    /* ---- SECURITY SECTION ---- */
    .security-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 16px;
      margin-bottom: 80px;
    }
    .security-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 22px;
      backdrop-filter: blur(10px);
      transition: transform 0.2s, border-color 0.2s;
    }
    .security-card:hover { transform: translateY(-3px); border-color: rgba(99,102,241,0.35); }
    .security-icon { font-size: 1.5rem; margin-bottom: 12px; }
    .security-title { font-size: 0.9rem; font-weight: 700; margin-bottom: 6px; }
    .security-desc  { font-size: 0.8rem; color: #64748b; line-height: 1.5; }

    /* ---- FOOTER ---- */
    footer {
      text-align: center;
      padding: 40px 24px;
      border-top: 1px solid var(--border);
      color: #64748b;
      font-size: 0.8rem;
    }
    footer span { color: var(--accent); }
  </style>
</head>
<body>

  <nav>
    <div class="nav-inner">
      <div class="logo">🔐 Fortress VNet</div>
      <div class="status-badge"><span class="dot"></span> Infrastructure Live</div>
    </div>
  </nav>

  <div class="container">
    <!-- HERO -->
    <section class="hero">
      <div class="eyebrow">Azure · Terraform · 3-Tier Architecture</div>
      <h1>Secure.<br /><span>Production-Grade.</span><br />Scalable.</h1>
      <p>A fully isolated, highly available 3-Tier Virtual Network on Microsoft Azure — provisioned entirely with Terraform, secured by NSGs, and powered by Private DNS.</p>
      <div class="hero-actions">
        <a href="#architecture" class="btn-primary">Explore Architecture ↓</a>
        <a href="#security" class="btn-secondary">Security Features →</a>
      </div>
    </section>

    <!-- STATS -->
    <div class="stats-row">
      <div class="stat-card"><div class="stat-value">3</div><div class="stat-label">Network Tiers</div></div>
      <div class="stat-card"><div class="stat-value">6+</div><div class="stat-label">Subnets</div></div>
      <div class="stat-card"><div class="stat-value">4</div><div class="stat-label">NSG Rulesets</div></div>
      <div class="stat-card"><div class="stat-value">100%</div><div class="stat-label">IaC Managed</div></div>
    </div>

    <!-- ARCHITECTURE -->
    <section id="architecture">
      <div class="section-header">
        <h2>Architecture Overview</h2>
        <p>Three isolated tiers, each with dedicated subnets and security rules.</p>
      </div>
      <div class="tier-grid">
        <div class="tier-card tier-1">
          <div class="tier-icon">🌐</div>
          <div class="tier-sub">Tier 1</div>
          <div class="tier-title">Public Web Layer</div>
          <ul class="tier-list">
            <li>Standard Public Load Balancer</li>
            <li>Static Public IP (SKU Standard)</li>
            <li>HTTP health probe on port 80</li>
            <li>Bastion Host for SSH jump access</li>
            <li>ALB NSG: Allow HTTP from internet</li>
          </ul>
        </div>
        <div class="tier-card tier-2">
          <div class="tier-icon">⚙️</div>
          <div class="tier-sub">Tier 2</div>
          <div class="tier-title">Private App Layer</div>
          <ul class="tier-list">
            <li>VM Scale Set (Ubuntu 22.04 LTS)</li>
            <li>Auto-scaled instances behind LB</li>
            <li>No direct inbound internet access</li>
            <li>Egress via NAT Gateway</li>
            <li>App NSG: Allow HTTP from ALB only</li>
          </ul>
        </div>
        <div class="tier-card tier-3">
          <div class="tier-icon">🗄️</div>
          <div class="tier-sub">Tier 3</div>
          <div class="tier-title">Isolated DB Layer</div>
          <ul class="tier-list">
            <li>PostgreSQL Flexible Server</li>
            <li>Delegated subnet (no public access)</li>
            <li>Private DNS Zone integration</li>
            <li>DB NSG: Allow port 5432 from App tier only</li>
            <li>Zero internet exposure</li>
          </ul>
        </div>
      </div>
    </section>

    <!-- SECURITY -->
    <section id="security">
      <div class="section-header">
        <h2>Security Features</h2>
        <p>Defense-in-depth with multiple layers of network isolation.</p>
      </div>
      <div class="security-grid">
        <div class="security-card">
          <div class="security-icon">🛡️</div>
          <div class="security-title">Network Security Groups</div>
          <div class="security-desc">Stateful firewalls on every subnet tier enforce least-privilege traffic rules.</div>
        </div>
        <div class="security-card">
          <div class="security-icon">🔑</div>
          <div class="security-title">SSH Key Authentication</div>
          <div class="security-desc">Password auth is disabled on all VMs. RSA SSH keys are mandatory.</div>
        </div>
        <div class="security-card">
          <div class="security-icon">🌉</div>
          <div class="security-title">Bastion Jump Host</div>
          <div class="security-desc">Private app instances are only reachable via a dedicated public bastion VM.</div>
        </div>
        <div class="security-card">
          <div class="security-icon">🔒</div>
          <div class="security-title">Private DNS Zones</div>
          <div class="security-desc">Database FQDN resolves only within the VNet — zero public DNS exposure.</div>
        </div>
        <div class="security-card">
          <div class="security-icon">📦</div>
          <div class="security-title">Remote Terraform State</div>
          <div class="security-desc">State is stored in Azure Blob Storage with encryption at rest and access controls.</div>
        </div>
        <div class="security-card">
          <div class="security-icon">🚦</div>
          <div class="security-title">NAT Gateway Egress</div>
          <div class="security-desc">All outbound traffic from private instances is routed through a controlled NAT Gateway.</div>
        </div>
      </div>
    </section>
  </div>

  <footer>
    Deployed with <span>Terraform</span> on <span>Microsoft Azure</span> &mdash; Fortress VNet &copy; 2026
  </footer>

</body>
</html>
HTMLEOF

# Ensure Nginx serves on port 80
nginx -t && systemctl reload nginx

echo "Fortress VNet init script completed successfully."
