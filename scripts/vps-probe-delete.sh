echo '=== wwwlogs dir ==='
ls -lat /www/wwwlogs/ 2>/dev/null | head -20
echo
echo '=== vhost configs mentioning api domain ==='
grep -rl 'api.hotpot1993' /www/server/panel/vhost/nginx/ 2>/dev/null
echo
echo '=== DELETE /api/v1/notifications in wwwlogs ==='
grep -h 'DELETE /api/v1/notifications' /www/wwwlogs/*.log 2>/dev/null | tail -40
echo
echo '=== api domain access log tail ==='
for f in /www/wwwlogs/*hotpot*.log; do
  [ -f "$f" ] || continue
  echo "-- $f (last 30)"
  tail -30 "$f"
done
echo
echo '=== cron aa lines ==='
crontab -l 2>/dev/null | grep -i 'aa\|sync'
echo
echo '=== sync script logs ==='
ls -la /opt/aa-split/logs/ 2>/dev/null
for f in /opt/aa-split/logs/*.log; do [ -f "$f" ] && echo "-- $f (tail 40)" && tail -40 "$f"; done
echo
echo '=== DB recent notifications ==='
docker exec aa-postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT id||char(9)||type||char(9)||left(title,20)||char(9)||\"isRead\"||char(9)||\"createdAt\" FROM \"Notification\" ORDER BY \"createdAt\" DESC LIMIT 15;"'
echo '=== done ==='
