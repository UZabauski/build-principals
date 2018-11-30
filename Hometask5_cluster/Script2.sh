#!/bin/bash
###jdk
sudo yum install -y wget
sudo yum install -y vim
sudo wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u191-b12/2787e4a523244c269598db4e85c51e0c/jdk-8u191-linux-x64.rpm"
sudo rpm -ivh jdk-8u191-linux-x64.rpm
sudo systemctl disable firewalld
sed -i 's/enforcing/disabled/g' /etc/selinux/config
###
sudo yum install -y gcc gcc-c++ git
sudo yum install -y wget
sudo wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.42.tar.gz
sudo tar xvf pcre-8.42.tar.gz
cd pcre-8.42
sudo ./configure
sudo make
sudo make install
cd /home/vagrant/
sudo wget https://www.openssl.org/source/openssl-1.0.2p.tar.gz 
sudo tar xvf openssl-1.0.2p.tar.gz
cd openssl-1.0.2p
sudo ./config
sudo make
sudo make install
cd /home/vagrant/
sudo mkdir nginx
cd /home/vagrant/nginx/
git clone git://github.com/vozlt/nginx-module-vts.git
sudo wget http://nginx.org/download/nginx-1.14.0.tar.gz
sudo tar xvf nginx-1.14.0.tar.gz
cd nginx-1.14.0
sudo ./configure --sbin-path=/home/vagrant/nginx/sbin/nginx --conf-path=/home/vagrant/nginx/conf/nginx.conf --error-log-path=/home/vagrant/nginx/logs/error.log --http-log-path=/home/vagrant/nginx/logs/access.log --pid-path=/home/vagrant/nginx/logs/nginx.pid --user=vagrant --with-http_ssl_module --with-http_realip_module --without-http_gzip_module --add-module=/home/vagrant/nginx/nginx-module-vts --with-openssl=/home/vagrant/openssl-1.0.2p --with-pcre=/home/vagrant/pcre-8.42
sudo make
sudo make install
###system.d
sudo printf "[Unit]\n" | sudo tee /etc/systemd/system/nginx.service
sudo printf "Description=The NGINX HTTP and reverse proxy server\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "After=syslog.target network.target remote-fs.target nss-lookup.target\n\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "[Service]\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "Type=forking\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "PIDFile=/home/vagrant/nginx/logs/nginx.pid\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "ExecStartPre=/home/vagrant/nginx/sbin/nginx -t\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "ExecStart=/home/vagrant/nginx/sbin/nginx\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "ExecReload=/home/vagrant/nginx/sbin/nginx -s reload\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "ExecStop=/bin/kill -s QUIT $MAINPID\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "PrivateTmp=true\n\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "[Install]\n" | sudo tee -a /etc/systemd/system/nginx.service
sudo printf "WantedBy=multi-user.target\n" | sudo tee -a /etc/systemd/system/nginx.service
###
cd /home/vagrant
sudo wget http://mirrors.jenkins.io/war-stable/latest/jenkins.war
cd /etc/systemd/system/
sudo touch jenkins.service
sudo chmod 777 jenkins.service
sudo printf "[Unit]\n" | sudo tee /etc/systemd/system/jenkins.service
sudo printf "Description=Jenkins Daemon\n\n" | sudo tee -a /etc/systemd/system/jenkins.service
sudo printf "[Service]\n" | sudo tee -a /etc/systemd/system/jenkins.service
sudo printf "ExecStart=/usr/bin/java -jar /home/vagrant/jenkins.war\n" | sudo tee -a /etc/systemd/system/jenkins.service
sudo printf "User=vagrant\n\n" | sudo tee -a /etc/systemd/system/jenkins.service
sudo printf "[Install]\n" | sudo tee -a /etc/systemd/system/jenkins.service
sudo printf "WantedBy=multi-user.target\n" | sudo tee -a /etc/systemd/system/jenkins.service
sudo systemctl daemon-reload
sudo systemctl start jenkins.service
sudo sh -c 'for line in 43 44 45 46; do sed  -i  "${line}s/^/#/" /home/vagrant/nginx/conf/nginx.conf; done'
sudo sed -i '38a\        location / {\' /home/vagrant/nginx/conf/nginx.conf
sudo sed -i '39a\            rewrite ^/(.*) /$1 break;\'  /home/vagrant/nginx/conf/nginx.conf
sudo sed -i '40a\            proxy_set_header   X-Real-IP $remote_addr;\'  /home/vagrant/nginx/conf/nginx.conf
sudo sed -i '41a\            proxy_set_header   Host      $http_host;\'  /home/vagrant/nginx/conf/nginx.conf
sudo sed -i '42a\            proxy_pass http://192.168.21.122:8080;\'  /home/vagrant/nginx/conf/nginx.conf
sudo sed -i '43a\}\'  /home/vagrant/nginx/conf/nginx.conf
sudo systemctl daemon-reload
sudo systemctl restart nginx
sudo systemctl start jenkins
sudo sh -c "echo -n 'admin:' >> /home/vagrant/nginx/conf/.htpasswd"
sudo sh -c "openssl passwd nginx >> /home/vagrant/nginx/conf/.htpasswd"
#sudo sh -c "echo -n 'admin:' >> /home/vagrant/nginx/conf/.htpasswd"
#sudo sh -c "openssl passwd nginx >> /home/vagrant/nginx/conf/.htpasswd"


















