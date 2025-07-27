# Grim & Scythe Operational Runbooks

## Table of Contents
1. [Emergency Response Procedures](#emergency-response-procedures)
2. [Deployment Procedures](#deployment-procedures)
3. [Monitoring and Alerting](#monitoring-and-alerting)
4. [Backup and Recovery](#backup-and-recovery)
5. [Security Incident Response](#security-incident-response)
6. [Performance Troubleshooting](#performance-troubleshooting)
7. [Database Maintenance](#database-maintenance)
8. [License Management](#license-management)

---

## Emergency Response Procedures

### Service Outage Response

**Symptoms:**
- Grim API returns 5xx errors
- Scythe license checks failing
- High error rates in monitoring dashboards

**Immediate Actions:**
1. **Check Service Status**
   ```bash
   # Check all services
   docker-compose -f docker-compose.prod.yml ps
   
   # Check individual service health
   curl -f http://grim-api:8080/health
   curl -f http://scythe-api:8081/health
   ```

2. **Check Logs**
   ```bash
   # Check recent logs
   docker-compose -f docker-compose.prod.yml logs --tail=100 grim-api
   docker-compose -f docker-compose.prod.yml logs --tail=100 scythe-api
   
   # Check system logs
   journalctl -u grim-api --since "10 minutes ago"
   ```

3. **Restart Services if Needed**
   ```bash
   # Restart specific service
   docker-compose -f docker-compose.prod.yml restart grim-api
   
   # Restart all services
   docker-compose -f docker-compose.prod.yml restart
   ```

4. **Escalate if Issues Persist**
   - Contact on-call engineer
   - Check infrastructure status
   - Consider rolling back to previous version

### Database Connection Issues

**Symptoms:**
- Database connection timeouts
- High database response times
- Connection pool exhaustion

**Immediate Actions:**
1. **Check Database Status**
   ```bash
   # Check PostgreSQL
   docker exec grim-postgres pg_isready -U grim_admin
   
   # Check connection count
   docker exec grim-postgres psql -U grim_admin -d grim -c "SELECT count(*) FROM pg_stat_activity;"
   ```

2. **Check Database Resources**
   ```bash
   # Check disk space
   docker exec grim-postgres df -h
   
   # Check memory usage
   docker exec grim-postgres free -h
   ```

3. **Restart Database if Necessary**
   ```bash
   docker-compose -f docker-compose.prod.yml restart grim-postgres
   ```

---

## Deployment Procedures

### Production Deployment

**Pre-deployment Checklist:**
- [ ] All tests passing in CI/CD
- [ ] Security scan completed
- [ ] Performance tests passed
- [ ] Backup completed
- [ ] Stakeholders notified

**Deployment Steps:**
1. **Create Backup**
   ```bash
   ./scripts/backup-manager.sh full
   ```

2. **Deploy to Production**
   ```bash
   # Pull latest images
   docker-compose -f docker-compose.prod.yml pull
   
   # Deploy with zero downtime
   docker-compose -f docker-compose.prod.yml up -d --no-deps grim-api
   docker-compose -f docker-compose.prod.yml up -d --no-deps scythe-api
   ```

3. **Verify Deployment**
   ```bash
   # Health checks
   curl -f http://grim-api:8080/health
   curl -f http://scythe-api:8081/health
   
   # Smoke tests
   ./scripts/smoke-tests.sh
   ```

4. **Monitor Post-deployment**
   - Watch error rates for 15 minutes
   - Check performance metrics
   - Verify all functionality

### Rollback Procedure

**If Issues Detected:**
1. **Immediate Rollback**
   ```bash
   # Rollback to previous version
   docker-compose -f docker-compose.prod.yml up -d --no-deps grim-api:previous
   docker-compose -f docker-compose.prod.yml up -d --no-deps scythe-api:previous
   ```

2. **Verify Rollback**
   ```bash
   # Health checks
   curl -f http://grim-api:8080/health
   curl -f http://scythe-api:8081/health
   ```

3. **Investigate Issues**
   - Review logs
   - Analyze metrics
   - Document findings

---

## Monitoring and Alerting

### Key Metrics to Monitor

**Grim System:**
- Backup success rate
- Compression ratios
- Storage usage
- API response times
- Error rates

**Scythe System:**
- License check success rate
- License violations
- API response times
- Database performance

**Infrastructure:**
- CPU usage
- Memory usage
- Disk usage
- Network I/O

### Alert Severity Levels

**Critical (Immediate Response Required):**
- Service completely down
- Database unavailable
- Security breach detected
- Data loss risk

**High (Response within 30 minutes):**
- High error rates (>5%)
- Performance degradation
- License violations
- Backup failures

**Medium (Response within 2 hours):**
- Elevated resource usage
- Slow response times
- Minor functionality issues

**Low (Response within 24 hours):**
- Informational alerts
- Maintenance notifications
- Performance warnings

### Alert Response Procedures

1. **Acknowledge Alert**
   - Respond to alert channel
   - Assess severity level
   - Begin investigation

2. **Investigate Issue**
   - Check monitoring dashboards
   - Review recent logs
   - Identify root cause

3. **Take Corrective Action**
   - Follow appropriate runbook
   - Implement fix
   - Verify resolution

4. **Document Incident**
   - Record timeline
   - Document actions taken
   - Update runbooks if needed

---

## Backup and Recovery

### Backup Verification

**Daily Checks:**
```bash
# Check backup status
./scripts/backup-manager.sh status

# Verify recent backups
./scripts/backup-manager.sh verify /backups/database_full_20250101_020000.sql.gz
```

**Weekly Tests:**
```bash
# Test recovery procedure
./scripts/backup-manager.sh recover /backups/database_full_20250101_020000.sql.gz database
```

### Disaster Recovery

**Complete System Recovery:**
1. **Stop All Services**
   ```bash
   docker-compose -f docker-compose.prod.yml down
   ```

2. **Restore Database**
   ```bash
   ./scripts/backup-manager.sh recover /backups/database_full_20250101_020000.sql.gz database
   ```

3. **Restore Configuration**
   ```bash
   ./scripts/backup-manager.sh recover /backups/config_20250101_020000.tar.gz configuration
   ```

4. **Restart Services**
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

5. **Verify Recovery**
   ```bash
   # Health checks
   curl -f http://grim-api:8080/health
   curl -f http://scythe-api:8081/health
   
   # Data integrity checks
   ./scripts/integrity-check.sh
   ```

---

## Security Incident Response

### Security Alert Response

**Immediate Actions:**
1. **Assess Threat Level**
   - Review alert details
   - Check affected systems
   - Determine scope

2. **Contain Threat**
   ```bash
   # Block malicious IPs
   ./scripts/security-monitor.sh block 192.168.1.100
   
   # Isolate affected systems
   docker-compose -f docker-compose.prod.yml stop grim-api
   ```

3. **Investigate Incident**
   - Review security logs
   - Check system integrity
   - Identify attack vector

4. **Remediate Issues**
   - Apply security patches
   - Update configurations
   - Restore from clean backup if needed

5. **Document Incident**
   - Record all actions taken
   - Update security procedures
   - Notify stakeholders

### License Violation Response

**Detection:**
- Monitor Scythe logs for violations
- Check license usage metrics
- Review customer reports

**Response:**
1. **Verify Violation**
   - Check license details
   - Confirm usage patterns
   - Review customer history

2. **Take Action**
   - Contact customer
   - Implement usage limits
   - Escalate if necessary

3. **Update Records**
   - Document violation
   - Update customer status
   - Track resolution

---

## Performance Troubleshooting

### High CPU Usage

**Investigation:**
```bash
# Check process CPU usage
docker exec grim-api top -bn1

# Check container metrics
docker stats grim-api

# Analyze CPU usage patterns
docker exec grim-api cat /proc/stat
```

**Common Solutions:**
- Scale up resources
- Optimize queries
- Add caching
- Reduce workload

### High Memory Usage

**Investigation:**
```bash
# Check memory usage
docker exec grim-api free -h

# Check memory by process
docker exec grim-api ps aux --sort=-%mem

# Check for memory leaks
docker exec grim-api cat /proc/meminfo
```

**Common Solutions:**
- Increase memory limits
- Optimize memory usage
- Restart services
- Add memory monitoring

### Slow Response Times

**Investigation:**
```bash
# Check API response times
curl -w "@curl-format.txt" -o /dev/null -s http://grim-api:8080/health

# Check database performance
docker exec grim-postgres psql -U grim_admin -d grim -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"

# Check network latency
ping grim-api
```

**Common Solutions:**
- Optimize database queries
- Add caching
- Scale horizontally
- Tune application settings

---

## Database Maintenance

### Regular Maintenance

**Daily:**
- Check backup status
- Monitor performance metrics
- Review error logs

**Weekly:**
- Analyze slow queries
- Update statistics
- Check disk usage

**Monthly:**
- Review and optimize indexes
- Clean up old data
- Update maintenance procedures

### Database Optimization

**Query Optimization:**
```sql
-- Find slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Analyze table statistics
ANALYZE backups;
ANALYZE security_events;
```

**Index Optimization:**
```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Create missing indexes
CREATE INDEX CONCURRENTLY idx_backups_created_at ON backups(created_at);
```

---

## License Management

### License Monitoring

**Daily Checks:**
- Monitor license usage
- Check for violations
- Review customer activity

**Weekly Reviews:**
- Analyze usage patterns
- Identify potential issues
- Update customer records

### License Violation Handling

**Detection:**
- Automated monitoring
- Customer reports
- Usage analysis

**Response:**
1. **Investigate**
   - Review usage data
   - Check customer history
   - Verify violation

2. **Contact Customer**
   - Explain situation
   - Offer solutions
   - Set expectations

3. **Take Action**
   - Implement restrictions
   - Update license terms
   - Escalate if needed

### License Renewal Process

**30 Days Before Expiry:**
- Send renewal reminder
- Review usage patterns
- Prepare renewal terms

**7 Days Before Expiry:**
- Send final reminder
- Offer assistance
- Prepare for expiration

**On Expiry:**
- Implement restrictions
- Contact customer
- Process renewal

---

## Emergency Contacts

**Primary On-Call:**
- Name: [Primary Engineer]
- Phone: [Phone Number]
- Email: [Email]

**Secondary On-Call:**
- Name: [Secondary Engineer]
- Phone: [Phone Number]
- Email: [Email]

**Management Escalation:**
- Name: [Manager]
- Phone: [Phone Number]
- Email: [Email]

**Security Team:**
- Email: security@grim.so
- Slack: #security-alerts

---

## Maintenance Windows

**Regular Maintenance:**
- Day: Sunday
- Time: 02:00-04:00 UTC
- Duration: 2 hours

**Emergency Maintenance:**
- As needed
- 24-hour notice when possible
- Immediate for critical issues

**Communication:**
- Email: maintenance@grim.so
- Slack: #maintenance
- Status page: status.grim.so 