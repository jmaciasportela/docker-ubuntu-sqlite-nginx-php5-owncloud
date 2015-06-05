FROM phusion/baseimage:latest
MAINTAINER Jesus Macias <jesus@owncloud.com>
ENV DEBIAN_FRONTEND noninteractive

# Set correct environment variables
ENV HOME /root
# Fix a Debianism of the nobody's uid being 65534
RUN usermod -u 99 nobody
RUN usermod -g 100 nobody

# Activar SSH
RUN rm -fr /etc/service/sshd/down

# Update root password
# CHANGE IT # to something like root:ASdSAdfÑ3
RUN echo "root:root" | chpasswd

# Enable ssh for root
RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
# Enable this option to prevent SSH drop connections
RUN printf "ServerAliveInterval 15\\nServerAliveCountMax 8" >> /etc/ssh/sshd_config

#Setup environment
ENV OC_URL http://download.owncloud.org/community/owncloud-daily-master.tar.bz2
ENV OC_ADMIN_USER admin
ENV OC_ADMIN_PASS Password
ENV DB_REMOTE_ROOT_PASS owncloud

# Push install script
ADD installoc.sh /etc/my_init.d/10_installoc.sh
RUN chmod +x /etc/my_init.d/10_installoc.sh

# Install owncloud dependencies
RUN apt-get update -q && apt-get install -y --force-yes nginx php5-fpm php5-sqlite php5-common php5-gd php-xml-parser php5-intl php5-mcrypt php5-curl php5-json php5-ldap php-soap php5-xdebug wget rsync sqlite3 unzip

# Modify php.ini
RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 5000M/g' /etc/php5/fpm/php.ini
RUN sed -i 's/post_max_size = 8M/post_max_size = 5000M/g' /etc/php5/fpm/php.ini
RUN sed -i 's/;default_charset = "UTF-8"/default_charset = "UTF-8"/g' /etc/php5/fpm/php.ini

#Enable Xdebug
# Added for xdebug
RUN printf "xdebug.remote_enable=1\\nxdebug.remote_handler=dbgp\\nxdebug.remote_mode=req\\nxdebug.remote_host=0.0.0.0\\nxdebug.remote_port=9000" >> /etc/php5/mods-available/xdebug.ini

RUN echo "daemon off;" >> /etc/nginx/nginx.conf
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini

# Generate selfsigned certificate
RUN mkdir /etc/nginx/ssl
RUN printf "ES\\nCYL\\nValladolid\\nOwncloud\\nDocker\\nyour.server.com\\n\\n" | openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -keyout /etc/apache2/ssl/server.key -out /etc/apache2/ssl/server.crt

# Configure nginx to run owncloud
RUN rm /etc/nginx/sites-enabled/default
ADD nginx_owncloud.conf /etc/nginx/sites-enabled/

# Install phpliteadmin
RUN wget -P /tmp https://phpliteadmin.googlecode.com/files/phpliteAdmin_v1-9-5.zip
RUN mkdir /opt/phpliteadmin
RUN unzip /tmp/phpliteAdmin_v1-9-5.zip -d /opt/phpliteadmin
RUN wget -P /tmp https://phpliteadmin.googlecode.com/files/phpliteadmin_themes_2013-12-26.zip
RUN unzip /tmp/phpliteadmin_themes_2013-12-26.zip -d /tmp
RUN cp /tmp/Modern/phpliteadmin.css /opt/phpliteadmin/
RUN sed -i 's/'\''admin'\'';/\$_SERVER\['\''DB_REMOTE_ROOT_PASS'\''\];/g' /opt/phpliteadmin/phpliteadmin.php
RUN sed -i 's/directory = '\''\.'\''/directory = '\''\/opt\/owncloud\/data'\''/g' /opt/phpliteadmin/phpliteadmin.php
RUN mv /opt/phpliteadmin/phpliteadmin.php /opt/phpliteadmin/index.php
RUN chown -R www-data: /opt/phpliteadmin

# Configure nginx service
RUN mkdir /etc/service/nginx
RUN echo '#!/usr/bin/env bash' > /etc/service/nginx/run
RUN echo 'nginx' >> /etc/service/nginx/run && chmod +x /etc/service/nginx/run

# Configure phpfpm service
RUN mkdir /etc/service/phpfpm
RUN echo '#!/usr/bin/env bash' > /etc/service/phpfpm/run
RUN echo 'php5-fpm -c /etc/php5/fpm' >> /etc/service/phpfpm/run && chmod +x /etc/service/phpfpm/run

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Autoconfig owncloud
ADD generate_autoconfig.php /root/generate_autoconfig.php

# Expose port. Cannot be modified!
EXPOSE 22 80 443 8080 9000

# Expose ownCloud's data dir
VOLUME ["/opt/owncloud/data"]

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]
