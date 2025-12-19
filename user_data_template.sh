#!/bin/bash
# user_data_template.sh
# Este script roda na inicialização de cada instância da Aplicação.

# --- 1. INSTALAÇÃO DE PACOTES ---
yum update -y
yum install -y httpd php php-cli php-mysqlnd php-json php-xml php-mbstring git

# --- 2. CONFIGURAÇÃO DE SERVIÇO (AREA DE TUNING) ---
systemctl start httpd
systemctl enable httpd

# --- 3. INSTALAÇÃO DO WORDPRESS (NÃO ALTERAR ABAIXO) ---
# Baixa e instala o WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Download do WordPress
cd /var/www/html
wp core download --allow-root

# Configuração do wp-config.php apontando para o DB da Arena
wp config create --dbname=wordpress --dbuser=wp_user --dbpass=wp_pass --dbhost=PLACEHOLDER_DB_IP --allow-root

# Permitir .htaccess para WordPress (permalinks)
cat <<CONF > /etc/httpd/conf.d/wp-override.conf
<Directory "/var/www/html">
   AllowOverride All
</Directory>
CONF

# Ajuste de permalinks e permissões
chown -R apache:apache /var/www/html
wp rewrite structure '/%postname%/' --hard --allow-root

# Criação do .htaccess padrão do WordPress
cat <<HTACCESS > /var/www/html/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS

# Ajuste das URLs para o DNS do Load Balancer
wp option update home 'http://PLACEHOLDER_LB_DNS' --allow-root
wp option update siteurl 'http://PLACEHOLDER_LB_DNS' --allow-root
chown apache:apache /var/www/html/.htaccess
chmod 644 /var/www/html/.htaccess

# --- TUNING DO APACHE (CONCORRÊNCIA + KEEPALIVE) ---
# Mais processos simultâneos (mais requisições em paralelo)
echo "ServerLimit 256" >> /etc/httpd/conf/httpd.conf
echo "MaxRequestWorkers 256" >> /etc/httpd/conf/httpd.conf

# Reaproveitar conexões sem prender worker demais
echo "KeepAlive On" >> /etc/httpd/conf/httpd.conf
echo "MaxKeepAliveRequests 200" >> /etc/httpd/conf/httpd.conf
echo "KeepAliveTimeout 2" >> /etc/httpd/conf/httpd.conf

# Reinicia o Apache com as novas configs
systemctl restart httpd
