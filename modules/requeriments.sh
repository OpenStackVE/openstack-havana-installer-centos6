#!/bin/bash
#
# Instalador desatendido para Openstack Havana sobre CENTOS
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# Octubre del 2013
#
# Script de instalacion y preparacion de pre-requisitos
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

#
# Verificaciones y taras de limpieza iniciales para evitar "opppss"
#

rm -rf /tmp/keystone-signing-*
rm -rf /tmp/cd_gen_*

epelinstalled=`rpm -qa|grep epel-release.\*noarch|wc -l`
amiroot=` whoami|grep root|wc -l`
amiarhel6=`cat /etc/redhat-release |grep 6.|wc -l`
internalbridgeinterface=`ifconfig $integration_bridge|grep -c $integration_bridge`
internalbridgepresent=`ovs-vsctl show|grep -i -c bridge.\*$integration_bridge`
oskernelinstalled=`uname -r|grep -c openstack.\*x86_64`

	
echo "Instalando paquetes iniciales"
echo ""

# Se instalan las dependencias principales vía yum
#
yum -y clean all
yum -y install yum-plugin-priorities yum-presto yum-plugin-changelog openstack-packstack
yum -y groupinstall Virtualization-Platform Virtualization-tools
yum -y install sudo gcc cpp make automake kernel-headers
yum -y install python-keystoneclient python-sqlalchemy python-migrate python-psycopg2 \
	MySQL-python python-tools python-sqlalchemy0.7 sysfsutils sg3_utils genisoimage \
	libguestfs glusterfs glusterfs-fuse nfs-utils sudo sheepdog libguestfs-tools-c
	
yum -y install tuned tuned-utils
echo "virtual-host" > /etc/tune-profiles/active-profile
chkconfig ksm on
chkconfig ksmtuned on
chkconfig tuned on

service ksm restart
service ksmtuned restart
service tuned restart

#
# Ya esto no es necesario
#tar -xzvf ./libs/sqlalchemy-migrate-0.7.2.tar.gz -C /usr/local/src/
#cd /usr/local/src/sqlalchemy-migrate-0.7.2/
#python ./setup.py install
#cd -

testlibvirt=`rpm -qi libvirt|grep -ci "is not installed"`

if [ $testlibvirt == "1" ]
then
	echo ""
	echo "Falló la instalación del prerequisito libvirt - abortando el resto de la instalación"
	echo ""
	exit 0
fi

packstackinstalled=`rpm -qa|grep openstack-packstack.\*noarch|wc -l`
searchtestnova=`yum search openstack-nova-common|grep openstack-nova-common.\*noarch|wc -l`


if [ $amiarhel6 == "1" ]
then
	echo ""
	echo "Ejecutando en un RHEL6 o Compatible - continuando"
	echo ""
else
	echo ""
	echo "No se pudo verificar que el sistema operativo es un RHEL6 o Compatible"
	echo "Abortando"
	echo ""
fi

if [ $epelinstalled == "1" ]
then
	echo ""
	echo "Epel Instalado - continuando"
else
	echo ""
	echo "Prerequisito inexistente: Repositorio EPEL no instalado"
	echo "Abortando"
	echo ""
	exit 0
fi

if [ $amiroot == "1" ]
then
	echo ""
	echo "Ejecutando como root - continuando"
	echo ""
else
	echo ""
	echo "ALERTA !!!. Este script debe ser ejecutado por el usuario root"
	echo "Abortando"
	echo ""
	exit 0
fi

if [ $oskernelinstalled == "1" ]
then
	echo ""
	echo "Kernel OpenStack RDO x86_64 detectado - continuando"
	echo ""
	else
	echo ""
	echo "ALERTA !!!. Este servidor no tiene el Kernel de RDO-Openstack instalado"
	echo "Abortando"
	echo ""
	exit 0
fi

if [ $packstackinstalled == "1" ]
then
	echo ""
	echo "Packstack instalado correctamente - continuando"
	echo ""
else
	echo ""
	echo "No se pudo verificar la existencia de Packstack"
	echo "Posible falla con repositorio RDO"
	echo "Abortando"
	echo ""
	exit 0
fi

if [ $searchtestnova == "1" ]
then
	echo ""
	echo "Repositorios RDO aparentemente en orden - continuando"
	echo ""
else
	echo ""
	echo "No se pudo verificar el correcto funcionamiento del repo RDO"
	echo "Abortando"
	echo ""
	exit 0
fi

if [ $internalbridgeinterface == "1" ]
then
	echo ""
	echo "Interfaz del bridge de integracion Presente - Continuando"
	echo ""
else
	echo ""
	echo "No se pudo encontrar la interfaz del bridge de integracion"
	echo "Abortando"
	echo ""
	exit 0
fi

if [ $internalbridgepresent == "1" ]
then
	echo ""
	echo "Bridge de integracion Presente - Continuando"
	echo ""
else
	echo ""
	echo "No se pudo encontrar el bridge de integracion"
	echo "Abortando"
	echo ""
	exit 0
fi

echo ""
echo "Pre-requisitos iniciales validados"
echo ""

echo "Preparando libvirt y limpiando configuración de IPTABLES"
echo "No se preocupe si ve un mensaje de FAILED"

if [ -f /etc/openstack-control-script-config/libvirt-installed ]
then
	echo "Libvirt y otros prerequisitos ya instalados"
else
	service libvirtd stop
	rm /etc/libvirt/qemu/networks/autostart/default.xml
	rm /etc/libvirt/qemu/networks/default.xml
	service iptables stop
	echo “” > /etc/sysconfig/iptables
	service libvirtd start
	chkconfig libvirtd on
	service iptables save
	service iptables start
	iptables -A INPUT -p tcp -m multiport --dports 22 -j ACCEPT
	service iptables save
	date > /etc/openstack-control-script-config/libvirt-installed
fi




