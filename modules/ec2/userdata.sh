#!/bin/bash
set -e

# ==========================================
# WordPress on Amazon Linux 2023 (x86_64)
# t3.micro optimized
# ==========================================

exec > /var/log/user-data.log 2>&1
echo "Starting user-data at $(date)"

# --- 1. Swap setup (insurance for t3.micro 1GB RAM) ---
fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# --- 2. Install packages ---
dnf update -y

# PHP and Apache (Amazon Linux 2023 uses 'php' not 'php8.2')
dnf install -y httpd php php-mysqlnd php-gd php-xml php-mbstring php-curl php-zip php-intl php-opcache mariadb105

# EFS utils for mounting
dnf install -y amazon-efs-utils

# --- 3. Start Apache ---
systemctl enable httpd
systemctl start httpd

# --- 4. Mount EFS to wp-content ---
mkdir -p /var/www/html/wp-content
mount -t efs -o tls ${efs_dns_name}:/ /var/www/html/wp-content || mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /var/www/html/wp-content

# Add to fstab for persistence
echo "${efs_dns_name}:/ /var/www/html/wp-content efs _netdev,tls 0 0" >> /etc/fstab

# --- 5. Wait for RDS to be available ---
echo "Waiting for RDS MySQL to be reachable..."
for i in $(seq 1 60); do
    if mysql -h "${db_host}" -u "${db_username}" -p"${db_password}" -e "SELECT 1" >/dev/null 2>&1; then
        echo "RDS is available!"
        break
    fi
    echo "Attempt $i/60: RDS not ready yet, waiting 10s..."
    sleep 10
done

# --- 6. Download WordPress ---
cd /tmp
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz

# Copy WordPress core (not wp-content, since EFS is mounted there)
cp -r /tmp/wordpress/* /var/www/html/

# Ensure wp-content directory structure exists on EFS
mkdir -p /var/www/html/wp-content/uploads
mkdir -p /var/www/html/wp-content/plugins
mkdir -p /var/www/html/wp-content/themes

# --- 7. Create wp-config.php with random salts ---
AUTH_KEY=$(openssl rand -base64 48)
SECURE_AUTH_KEY=$(openssl rand -base64 48)
LOGGED_IN_KEY=$(openssl rand -base64 48)
NONCE_KEY=$(openssl rand -base64 48)
AUTH_SALT=$(openssl rand -base64 48)
SECURE_AUTH_SALT=$(openssl rand -base64 48)
LOGGED_IN_SALT=$(openssl rand -base64 48)
NONCE_SALT=$(openssl rand -base64 48)

cat > /var/www/html/wp-config.php << EOF
<?php
define( 'DB_NAME', '${db_name}' );
define( 'DB_USER', '${db_username}' );
define( 'DB_PASSWORD', '${db_password}' );
define( 'DB_HOST', '${db_host}' );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

define('AUTH_KEY',         '\$AUTH_KEY');
define('SECURE_AUTH_KEY',  '\$SECURE_AUTH_KEY');
define('LOGGED_IN_KEY',    '\$LOGGED_IN_KEY');
define('NONCE_KEY',        '\$NONCE_KEY');
define('AUTH_SALT',        '\$AUTH_SALT');
define('SECURE_AUTH_SALT', '\$SECURE_AUTH_SALT');
define('LOGGED_IN_SALT',   '\$LOGGED_IN_SALT');
define('NONCE_SALT',       '\$NONCE_SALT');

\$table_prefix = 'wp_';

define( 'WP_DEBUG', false );
define( 'FS_METHOD', 'direct' );

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
EOF

# --- 8. Permissions ---
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# --- 9. PHP optimization ---
cat >> /etc/php.ini << 'PHPEOF'

; WordPress optimizations
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
max_input_time = 300
max_input_vars = 3000
PHPEOF

# OPcache settings
cat > /etc/php.d/10-opcache.ini << 'OPCACHEEOF'
zend_extension=opcache.so
opcache.memory_consumption=64
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
opcache.enable=1
OPCACHEEOF

# --- 10. Apache config with security headers ---
cat > /etc/httpd/conf.d/wordpress.conf << 'APACHEEOF'
<VirtualHost *:80>
    ServerName qp001.blog
    ServerAlias www.qp001.blog
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/wordpress-error.log
    CustomLog /var/log/httpd/wordpress-access.log combined
</VirtualHost>

# Security headers
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
</IfModule>

# Hide server version
ServerTokens Prod
ServerSignature Off
APACHEEOF

# Enable mod_rewrite and mod_headers
sed -i 's/^#LoadModule rewrite_module/LoadModule rewrite_module/' /etc/httpd/conf/httpd.conf || true
sed -i 's/^#LoadModule headers_module/LoadModule headers_module/' /etc/httpd/conf/httpd.conf || true

# --- 11. Install certbot ---
# Amazon Linux 2023: use certbot from pip as dnf package may not be available
pip3 install certbot 2>/dev/null || pip install certbot

# Create a wrapper script for certbot with Apache
 cat > /usr/local/bin/certbot-apache-wrapper << 'CERTEOF'
#!/bin/bash
# Manual certbot execution for Apache on Amazon Linux 2023
certbot certonly --apache -d qp001.blog -d www.qp001.blog --non-interactive --agree-tos -m ${alert_email} --redirect
CERTEOF
chmod +x /usr/local/bin/certbot-apache-wrapper

# --- 12. Restart Apache ---
systemctl restart httpd

# --- 13. Auto-run certbot via cron ---
cat > /etc/cron.d/certbot-renew << CRONEOF
# Certbot renewal (runs twice daily)
0 */12 * * * root certbot renew --quiet
# Initial certbot run (DNS may need time to propagate)
0 4 * * * root /usr/local/bin/certbot-apache-wrapper || true
CRONEOF

# Try certbot once now (often fails until Route53 propagates, that's OK)
sleep 30
/usr/local/bin/certbot-apache-wrapper || echo "Certbot initial run failed - will retry via cron"

# --- 14. Secure logs (remove sensitive data) ---
shred -uf /var/log/user-data.log 2>/dev/null || rm -f /var/log/user-data.log
shred -uf /var/log/cloud-init-output.log 2>/dev/null || rm -f /var/log/cloud-init-output.log

echo "user-data completed at $(date)"
