echo '=== vhost conf (api domain) ==='
cat /www/server/panel/vhost/nginx/api.hotpot1993.top.conf
echo
echo '=== vhost conf.bak ==='
cat /www/server/panel/vhost/nginx/api.hotpot1993.top.conf.bak-1787727890 2>/dev/null | head -40
echo
echo '=== load_balancing dir ==='
find /www/wwwlogs/load_balancing -type f 2>/dev/null | head
echo
echo '=== all DELETE notifications: day/time/status (full log) ==='
grep -h 'DELETE /api/v1/notifications' /www/wwwlogs/api.hotpot1993.top.log | awk '{print $4, $6, $7, $9, $10}' | sed 's/\[//' 
echo
echo '=== full history of id 20b92586 ==='
grep -h '20b92586' /www/wwwlogs/api.hotpot1993.top.log | head -20
echo
echo '=== full history of id 676353c6 ==='
grep -h '676353c6' /www/wwwlogs/api.hotpot1993.top.log | head -20
echo
echo '=== DB: recent notifications ==='
docker exec aa-postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, type, left(title,20) AS title, \"isRead\", \"createdAt\" FROM \"Notification\" ORDER BY \"createdAt\" DESC LIMIT 12;"'
echo '=== DB: total count ==='
docker exec aa-postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM \"Notification\";"'
echo '=== done ==='
