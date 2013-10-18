#!/bin/bash
#
# Instalador desatendido para Openstack Havana sobre CENTOS
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# Octubre del 2013
#
# Script para instalacion de Message Broker
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

if [ -f ./configs/main-config.rc ]
then
	source ./configs/main-config.rc
	mkdir -p /etc/openstack-control-script-config
else
	echo "No puedo acceder a mi archivo de configuración"
	echo "Revise que esté ejecutando el instalador/módulos en el directorio correcto"
	echo "Abortando !!!!."
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/broker-installed ]
then
	echo ""
	echo "Aparentemente este módulo ya se ejecutó de manera exitosa"
	echo "Message Broker previamente instalado"
	echo ""
	exit 0
fi

	echo ""
	echo "Instalando paquetes para el Messagebroker"

case $brokerflavor in
"qpid")
	yum -y install qpid-cpp-server qpid-cpp-server-ssl qpid-cpp-client cyrus-sasl cyrus-sasl-md5 cyrus-sasl-plain
	yum -y erase cyrus-sasl-gssapi

	echo ""
	echo "Listo"
	echo ""

	echo "Configurando el messagebroker"

	echo "cluster-mechanism=DIGEST-MD5 ANONYMOUS" > /etc/qpidd.conf
	echo "auth=yes" >> /etc/qpidd.conf
	echo "realm=QPID" >> /etc/qpidd.conf

	echo "$brokerpass"|saslpasswd2 -f /var/lib/qpidd/qpidd.sasldb -u QPID $brokeruser -p

	service saslauthd restart
	chkconfig saslauthd on

	echo "Listo"

	echo ""
	echo "Activando Servicio de Messagebroker"

	chkconfig qpidd on
	service qpidd restart

	echo "Listo"
	echo ""

	qpidtest=`rpm -qi qpid-cpp-server|grep -ci "is not installed"`
	if [ $qpidtest == "1" ]
	then
		echo ""
		echo "Falló la instalación del message broker - abortando el resto de la instalación"
		echo ""
		exit 0
	else
		date > /etc/openstack-control-script-config/broker-installed
	fi
	;;

"rabbitmq")

	yum -y install rabbitmq-server

	chkconfig rabbitmq-server on
	service rabbitmq-server restart

	rabbitmqctl add_vhost $brokervhost
	rabbitmqctl list_vhosts

	rabbitmqctl add_user $brokeruser $brokerpass
	rabbitmqctl list_users

	rabbitmqctl set_permissions -p $brokervhost $brokeruser ".*" ".*" ".*"
	rabbitmqctl list_permissions -p $brokervhost

	rabbitmqtest=`rpm -qi rabbitmq-server|grep -ci "is not installed"`
	if [ $rabbitmqtest == "1" ]
	then
		echo ""
		echo "Falló la instalación del message broker - abortando el resto de la instalación"
		echo ""
		exit 0
	else
		date > /etc/openstack-control-script-config/broker-installed
	fi

	;;
esac

echo "Aplicando reglas de IPTABLES"

iptables -I INPUT -p tcp -m tcp --dport 5672 -j ACCEPT
service iptables save

echo "Listo"

echo ""
echo "Servicio de Message Broker Instalado"
echo ""


