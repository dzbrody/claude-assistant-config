<?php
// /var/www/html/config/redis.config.php
// Merged automatically by Nextcloud at startup.
// Provides Redis-backed memory caching (APCu for local, Redis for distributed).

$CONFIG = array(
  'memcache.local'      => '\\OC\\Memcache\\APCu',
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking'    => '\\OC\\Memcache\\Redis',
  'redis' => array(
    'host'    => 'nextcloud-redis',
    'port'    => 6379,
    'timeout' => 1.5,
  ),
  // Background job mode (cron container handles this)
  'backgroundjobs_mode' => 'cron',
  // Disable bruteforce throttle in loopback (nginx proxied)
  'auth.bruteforce.protection.enabled' => true,
);
