MYSQL_HOST=localhost
MYSQL_ROOT_PASSWORD=root
MYSQL_USER=magento
MYSQL_PASSWORD=magento123
MYSQL_DATABASE=magento
MAGENTO_VERSION="2.4.4"
WWW_DIR="/var/www"
INSTALL_DIR="${WWW_DIR}/html"
COMPOSER_HOME="${WWW_DIR}/.composer"
WEB_USER="www-data"
GROUP="www-data"


#Start the updates
set -ex
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install nginx -y
#Install 
sudo apt-get install software-properties-common
sudo apt install -y mariadb-server 
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo systemctl status mariadb
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.16.1-arm64.deb
sudo dpkg -i elasticsearch-7.16.1-arm64.deb
sudo systemctl start elasticsearch
sudo systemctl status elasticsearch --no-pager
sudo add-apt-repository ppa:ondrej/nginx -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update
sudo apt-get install php7.4-bcmath php7.4-common php7.4-curl php7.4-fpm php7.4-gd php7.4-intl php7.4-mbstring php7.4-mysql php7.4-soap php7.4-xml php7.4-xsl php7.4-zip php7.4-xdebug -y  
sudo apt upgrade -y -y 




sudo mysql --user=root <<_EOF_
    UPDATE mysql.user SET Password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    FLUSH PRIVILEGES;
_EOF_

sudo mysql -u root -p${MYSQL_ROOT_PASSWORD} <<EOF
    CREATE USER ${MYSQL_USER}@${MYSQL_HOST} IDENTIFIED BY "${MYSQL_PASSWORD}";
    CREATE DATABASE ${MYSQL_DATABASE};
    GRANT ALL ON ${MYSQL_DATABASE}.* TO ${MYSQL_USER}@${MYSQL_HOST};
    FLUSH PRIVILEGES;
    exit
EOF


sudo passwd -d ${WEB_USER}
sudo usermod -a -G ${GROUP} ${WEB_USER}


sudo curl -sS https://getcomposer.org/installer | sudo php
sudo mv composer.phar /usr/local/bin/composer
sudo /usr/local/bin/composer self-update --2
sudo mkdir ${COMPOSER_HOME}
sudo sh -c "echo '{
  \"http-basic\": {
    \"repo.magento.com\": {
      \"username\": \"5310458a34d580de1700dfe826ff19a1\",
      \"password\": \"255059b03eb9d30604d5ef52fca7465d\"
    }
  }
}' > ${COMPOSER_HOME}/auth.json"

sudo chsh -s /usr/bin/bash ${WEB_USER}
cd /tmp
sudo curl https://codeload.github.com/magento/magento2/tar.gz/$MAGENTO_VERSION -o $MAGENTO_VERSION.tar.gz
sudo tar xvf $MAGENTO_VERSION.tar.gz
sudo mv magento2-$MAGENTO_VERSION/* /var/www/html
sudo chown -R ${WEB_USER}:${WEB_USER} ${WWW_DIR}

sudo sh -c "echo 'max_input_time = 30
memory_limit= 2G
error_reporting = E_COMPILE_ERROR|E_RECOVERABLE_ERROR|E_ERROR|E_CORE_ERROR
error_log = /var/log/php/error.log
date.timezone = Europe/Amsterdam' >> /etc/php.ini"

sudo tee -a /etc/nginx/sites-available/magento <<EOF
upstream fastcgi_backend {
  server  unix:/run/php/php7.4-fpm.sock;
}

server {

  listen 80;
  server_name 10.211.55.3;
  set \$MAGE_ROOT /var/www/html;
  include /var/www/html/nginx.conf.sample;
}

EOF

sudo ln -s /etc/nginx/sites-available/magento /etc/nginx/sites-enabled/magento
sudo systemctl restart nginx  
sudo -u www-data composer install --working-dir=/var/www/html
sudo -u www-data composer config repositories.magento composer https://repo.magento.com/ --working-dir=/var/www/html
sudo -u www-data /var/www/html/bin/magento setup:install --base-url=http://10.211.55.3/ --db-host=localhost --db-name=magento --db-user=magento --db-password=magento123 --backend-frontname=admin --admin-firstname=admin --admin-lastname=LastName --admin-email=youremail@mail.com --admin-user=admin --admin-password=magento123 --language=en_US --currency=EUR --timezone=Europe/Amsterdam --use-rewrites=0
sudo -u www-data /var/www/html/bin/magento setup:upgrade
sudo -u www-data /var/www/html/bin/magento cache:flush

#enable ssh password access for IDE deployment
sudo sed -i.bak 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i.bak 's/^ChallengeResponseAuthentication .*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
