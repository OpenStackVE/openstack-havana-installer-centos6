#!/bin/bash
#
# Instalador desatendido para Openstack Havana sobre CENTOS
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# Octubre del 2013
#
# Script para instalacion de monitoreo SNMP
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

if [ -f /etc/openstack-control-script-config/db-installed ]
then
	echo ""
	echo "Proceso de BD verificado - continuando"
	echo ""
else
	echo ""
	echo "Este módulo depende de que el proceso de base de datos"
	echo "haya sido exitoso, pero aparentemente no lo fue"
	echo "Abortando el módulo"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/keystone-installed ]
then
	echo ""
	echo "Proceso principal de Keystone verificado - continuando"
	echo ""
else
	echo ""
	echo "Este módulo depende del proceso principal de keystone"
	echo "pero no se pudo verificar que dicho proceso haya sido"
	echo "completado exitosamente - se abortará el proceso"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/snmp-installed ]
then
	echo ""
	echo "Este módulo ya fue ejecutado de manera exitosa - saliendo"
	echo ""
	exit 0
fi



if [ -f /etc/snmp/snmpd.conf ]
then
	snmpdconfpresent="yes"
	cp -v /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.pre-openstack
else
	snmpdconfpresent="no"
fi

echo ""
echo "Instalando software para monitoreo"
echo ""

yum -y install net-snmp-utils net-snmp net-snmp-libs virt-top

cp -v ./libs/snmp/scripts/* /usr/local/bin/
chmod a+x /usr/local/bin/*.sh

cp -v ./libs/snmp/crontab/openstack-monitor.crontab /etc/cron.d/
chmod 644 /etc/cron.d/openstack-monitor.crontab
service crond reload

case $snmpdconfpresent in
yes)
	cat ./libs/snmp/conf/snmpd.conf.body >> /etc/snmp/snmpd.conf
	;;
no)
	cat ./libs/snmp/conf/snmpd.conf.header > /etc/snmp/snmpd.conf
	cat ./libs/snmp/conf/snmpd.conf.body >> /etc/snmp/snmpd.conf
	;;
esac

service snmpd restart

echo ""
echo "Aplicando reglas de IPTABLES"
echo ""

iptables -I INPUT -p udp -m udp --dport 161 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 161 -j ACCEPT
service iptables save

# NOTA: Como el módulo de snmp NO ES crítico, no nos molestamos en siquiera
# revisar si se instaló o no - wtf !!!.
date > /etc/openstack-control-script-config/snmp
date > /etc/openstack-control-script-config/snmp-installed

echo ""
echo "Infraestructura de monitoreo vía SNMP instalada"
echo ""
