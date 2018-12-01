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

sudo firewall-cmd --zone=public --add-port=22/tcp --permanent
sudo firewall-cmd --reload
sudo systemctl daemon-reload
sudo systemctl stop firewalld
#cd /home/vagrant/.ssh/; ssh-keygen -t rsa -C "Jenkins agent key" -f "jenkinsAgent_rsa"
#cat /home/vagrant/.ssh/jenkinsAgent_rsa.pub >> /home/vagrant/.ssh/authorized_keys



