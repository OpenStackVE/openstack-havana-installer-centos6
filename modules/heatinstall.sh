#!/bin/bash
#
# Instalador desatendido para Openstack Havana sobre CENTOS
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# Octubre del 2013
#
# Script de instalacion y preparacion de Heat
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

if [ -f /etc/openstack-control-script-config/ceilometer-installed ]
then
	echo ""
	echo "Este módulo ya fue ejecutado de manera exitosa - saliendo"
	echo ""
	exit 0
fi


echo ""
echo "Instalando paquetes para Ceilometer"

yum install -y openstack-heat-api \
	openstack-heat-api-cfn \
	openstack-heat-common \
	python-heatclient \
	openstack-heat-engine \
	heat-cfntools \
	openstack-utils \
	openstack-selinux

echo "Listo"
echo ""

cat ./libs/openstack-config > /usr/bin/openstack-config

source $keystone_admin_rc_file

echo ""
echo "Configurando Heat"
echo ""

openstack-config --set /etc/heat/api-paste.ini "[filter:authtoken]" paste.filter_factory "heat.common.auth_token:filter_factory"
openstack-config --set /etc/heat/api-paste.ini "[filter:authtoken]" auth_host $keystonehost
openstack-config --set /etc/heat/api-paste.ini "[filter:authtoken]" auth_port 35357
openstack-config --set /etc/heat/api-paste.ini "[filter:authtoken]" auth_protocol http
openstack-config --set /etc/heat/api-paste.ini "[filter:authtoken]" admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/heat/api-paste.ini "[filter:authtoken]" admin_user $heatuser
openstack-config --set /etc/heat/api-paste.ini "[filter:authtoken]" admin_password $heatpass

case $dbflavor in
"mysql")
	openstack-config --set /etc/heat/heat.conf database connection mysql://$heatdbuser:$heatdbpass@$dbbackendhost:$mysqldbport/$heatdbname
	;;
"postgres")
	openstack-config --set /etc/heat/heat.conf database connection postgresql://$heatdbuser:$heatdbpass@$dbbackendhost:$psqldbport/$heatdbname
	;;
esac

echo ""
echo "Heat Configurado"
echo ""

#
# Se aprovisiona la base de datos
echo ""
echo "Aprovisionando/inicializando BD de HEAT"
echo ""
heat-manage db_sync

echo ""
echo "Listo"
echo ""

echo ""
echo "Aplicando reglas de IPTABLES"

iptables -A INPUT -p tcp -m multiport --dports 8000,8004 -j ACCEPT
service iptables save

echo "Listo"

echo ""
echo "Activando Servicios"
echo ""

service openstack-heat-api start
service openstack-heat-api-cfn start
service openstack-heat-engine start
chkconfig openstack-heat-api on
chkconfig openstack-heat-api-cfn on
chkconfig openstack-heat-engine on

testheat=`rpm -qi openstack-heat-common|grep -ci "is not installed"`
if [ $testheat == "1" ]
then
	echo ""
	echo "Falló la instalación de heat - abortando el resto de la instalación"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/heat-installed
	date > /etc/openstack-control-script-config/heat
fi


echo ""
echo "Heat Instalado"
echo ""



