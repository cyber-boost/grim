# 🏗️ CORRECTED GRIM ARCHITECTURE - PM2 MANAGED

## **🎯 DOMAIN → PORT MAPPING**

### **Port 4746 (Grim Admin Server) - Main Admin Interface:**
- **grim.so** - Main admin interface and landing page
- **rip.grim.so** - Secondary admin interface  
- **rp.grim.so** - Another admin interface
- **Routes:** All routes (/, /admin, /api/, /health, /static/, /assets/)
- **Features:** Admin dashboard, billing, monitoring, security, public pages
- **Management:** Systemd/Gunicorn (not PM2)

### **Port 4747 (Mother DB API) - License System:**
- **Route:** `rip.grim.so/scythe/`
- **Endpoints:**
  - `/scythe/validate` - License validation
  - `/scythe/register` - Installation registration  
  - `/scythe/heartbeat` - Heartbeat monitoring
  - `/scythe/vendor/register` - Vendor registration
  - `/scythe/admin/stats` - Admin stats
  - `/scythe/validate-user-license` - User license validation
- **Management:** PM2 (`mother-db-api`)

### **Port 4748 (Vendor API) - CLI License Management:**
- **Route:** `rip.grim.so/vendor-api/`
- **Purpose:** Vendor API for CLI users to manage licenses
- **Management:** PM2 (`simple-vendor-api`)

### **Port 4749 (Affiliate System) - Revenue Sharing:**
- **Routes:** 
  - `grim.so/underworld/<affiliate_id>` - Affiliate landing pages
  - `/api/affiliate/` - Affiliate API endpoints
- **Purpose:** BBL 33% revenue sharing system
- **Management:** PM2 (`grim-affiliate-system`)

## **🔧 CURRENT PM2 SERVICES**

```bash
pm2 list
# ✅ mother-db-api (Port 4747)
# ✅ grim-affiliate-system (Port 4749) 
# ✅ simple-vendor-api (Port 4748)
# ❌ grim-server (Port 4746) - Should be Systemd/Gunicorn instead
```

## **🚨 WHAT NEEDS TO BE FIXED**

### **1. Admin Server Management:**
- Move `grim-server` from PM2 to proper Systemd/Gunicorn
- Create `/etc/systemd/system/grim-admin.service`
- Use gunicorn for production WSGI serving

### **2. Nginx Routing Updates:**
```nginx
# Add to grim.so nginx config
location /underworld/ {
    proxy_pass http://127.0.0.1:4749/underworld/;
    # ... proxy headers
}

# Add to grim.so nginx config  
location /api/affiliate/ {
    proxy_pass http://127.0.0.1:4749/api/affiliate/;
    # ... proxy headers
}
```

### **3. Compression Analytics Endpoint:**
- Add `/api/compression/analytics` to admin server (port 4746)
- CLI sends compression data to `rip.grim.so/api/compression/analytics`
- Nginx routes to admin server, admin server stores in GRIMS_MOTHER DB

## **📁 KEY FILES LOCATIONS**

```
/opt/reaper/tsk_flask/
├── grim_admin_server.py          # Port 4746 (Systemd)
├── mother_db_pm2.py              # Port 4747 (PM2)
├── simple_vendor_api.py          # Port 4748 (PM2)
├── grim_affiliate_system.py      # Port 4749 (PM2)
├── ecosystem.config.js           # PM2 configuration
└── grim-admin.service            # Systemd service (to create)
```

## **⚡ NEXT STEPS**

1. **Create systemd service** for admin server (port 4746)
2. **Remove grim-server from PM2** 
3. **Add nginx routes** for affiliate system (port 4749)
4. **Add compression analytics** to admin server
5. **Test all endpoints** work correctly

## **🎯 FINAL ARCHITECTURE**

```
CLI Users → nginx → Backend Services

Domains:
grim.so     → Port 4746 (Admin + Public pages)
rip.grim.so → Port 4746 (Admin + API) + Port 4747 (Scythe) + Port 4748 (Vendor)
rp.grim.so  → Port 4746 (Admin interface)

PM2 Managed:
- mother-db-api (4747)
- grim-affiliate-system (4749)  
- simple-vendor-api (4748)

Systemd Managed:
- grim-admin-server (4746)
```

This separation makes sense:
- **PM2** manages the smaller, specialized APIs
- **Systemd + Gunicorn** manages the main admin server (heavier workload)
- **Nginx** routes everything properly
- **Clean port separation** prevents conflicts