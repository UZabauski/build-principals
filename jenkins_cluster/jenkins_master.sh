#!/bin/bash
su - vagrant
sudo yum install -y net-tools git 

#install java 8
sudo wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u191-b12/2787e4a523244c269598db4e85c51e0c/jdk-8u191-linux-x64.rpm"
sudo yum localinstall -y jdk-8u191-linux-x64.rpm
java -version

sudo wget http://ftp.byfly.by/pub/apache.org/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz
sudo mkdir /opt/maven
mv apache-maven-3.6.0-bin.tar.gz /opt/maven
sudo tar xvzf /opt/maven/apache-maven-3.6.0-bin.tar.gz

echo "export PATH=/opt/maven/apache-maven-3.6.0/bin:\$PATH" >> /home/vagrant/.bashrc
source /home/vagrant/.bashrc

#install jenkins
sudo wget http://mirrors.jenkins.io/war-stable/latest/jenkins.war
mkdir /opt/jenkins
mv /home/vagrant/jenkins.war /opt/jenkins
sudo chown -R vagrant:vagrant /opt

#Systemd  File
sudo touch /etc/systemd/system/jenkins.service
sudo cat > /etc/systemd/system/jenkins.service <<EOF
[Unit]
Description=Jenkins Daemon
After=network.target
[Service]
ExecStart=/usr/bin/java -Xms1500M -Xmx3000M -jar /opt/jenkins/jenkins.war
User=vagrant
Restart=always
[Install]
WantedBy=multi-user.target
EOF
#install nginx
sudo yum install -y epel-release
sudo yum install -y nginx
sudo sed -i '/^[^#].*location \/ {/a  proxy_pass    http://192.168.115.70:8080;' /etc/nginx/nginx.conf
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl enable nginx
sudo systemctl start jenkins
sudo systemctl start nginx

sudo firewall-cmd --zone=public --add-port=22/tcp --permanent
sudo firewall-cmd --reload
sudo systemctl daemon-reload
sudo systemctl stop firewalld
#cd /home/vagrant/.ssh/; ssh-keygen -t rsa -C "Jenkins agent key" -f "jenkinsAgent_rsa"
#cat /home/vagrant/.ssh/jenkinsAgent_rsa.pub >> /home/vagrant/.ssh/authorized_keys



