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

if [ -f /etc/openstack-control-script-config/heat-installed ]
then
	echo ""
	echo "Este módulo ya fue ejecutado de manera exitosa - saliendo"
	echo ""
	exit 0
fi


echo ""
echo "Instalando paquetes para Heat"

yum install -y openstack-heat-api \
	openstack-heat-api-cfn \
	openstack-heat-common \
	python-heatclient \
	openstack-heat-engine \
	openstack-utils \
	openstack-selinux

echo "Listo"
echo ""

cat ./libs/openstack-config > /usr/bin/openstack-config

source $keystone_admin_rc_file

echo ""
echo "Configurando Heat"
echo ""

# Temporal - aparentemente el paquete no instala el api-paste.ini

cat ./libs/heat/api-paste.ini > /etc/heat/api-paste.ini

chown -R heat.heat /etc/heat

openstack-config --set /etc/heat/api-paste.ini "filter:authtoken" paste.filter_factory "heat.common.auth_token:filter_factory"
openstack-config --set /etc/heat/api-paste.ini "filter:authtoken" auth_host $keystonehost
openstack-config --set /etc/heat/api-paste.ini "filter:authtoken" auth_port 35357
openstack-config --set /etc/heat/api-paste.ini "filter:authtoken" auth_protocol http
openstack-config --set /etc/heat/api-paste.ini "filter:authtoken" admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/heat/api-paste.ini "filter:authtoken" admin_user $heatuser
openstack-config --set /etc/heat/api-paste.ini "filter:authtoken" admin_password $heatpass

echo "# Heat Main Config" >> /etc/heat/heat.conf

case $dbflavor in
"mysql")
	openstack-config --set /etc/heat/heat.conf database connection mysql://$heatdbuser:$heatdbpass@$dbbackendhost:$mysqldbport/$heatdbname
	openstack-config --set /etc/heat/heat.conf DEFAULT sql_connection mysql://$heatdbuser:$heatdbpass@$dbbackendhost:$mysqldbport/$heatdbname
	;;
"postgres")
	openstack-config --set /etc/heat/heat.conf database connection postgresql://$heatdbuser:$heatdbpass@$dbbackendhost:$psqldbport/$heatdbname
	openstack-config --set /etc/heat/heat.conf DEFAULT sql_connection postgresql://$heatdbuser:$heatdbpass@$dbbackendhost:$psqldbport/$heatdbname
	;;
esac

openstack-config --set /etc/heat/heat.conf DEFAULT host $heathost
openstack-config --set /etc/heat/heat.conf DEFAULT debug false
openstack-config --set /etc/heat/heat.conf DEFAULT verbose false
openstack-config --set /etc/heat/heat.conf DEFAULT log_dir /var/log/heat

openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_user $heatuser
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_password $heatpass
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_host $keystonehost
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_uri http://$keystonehost:5000/v2.0/
openstack-config --set /etc/heat/heat.conf keystone_authtoken signing_dir /tmp/keystone-signing-heat

openstack-config --set /etc/heat/heat.conf DEFAULT control_exchange openstack

case $brokerflavor in
"qpid")
        openstack-config --set /etc/heat/heat.conf DEFAULT rpc_backend heat.openstack.common.rpc.impl_qpid
        openstack-config --set /etc/heat/heat.conf DEFAULT qpid_reconnect_interval_min 0
        openstack-config --set /etc/heat/heat.conf DEFAULT qpid_username $brokeruser
        openstack-config --set /etc/heat/heat.conf DEFAULT qpid_tcp_nodelay True
        openstack-config --set /etc/heat/heat.conf DEFAULT qpid_protocol tcp
        openstack-config --set /etc/heat/heat.conf DEFAULT qpid_hostname $messagebrokerhost
        openstack-config --set /etc/heat/heat.conf DEFAULT qpid_password $brokerpass
        openstack-config --set /etc/heat/heat.conf DEFAULT qpid_port 5672
        openstack-config --set /etc/heat/heat.conf DEFAULT qpid_topology_version 1
        ;;

"rabbitmq")
        openstack-config --set /etc/heat/heat.conf DEFAULT rpc_backend heat.openstack.common.rpc.impl_kombu
        openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_host $messagebrokerhost
        openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_userid $brokeruser
        openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_password $brokerpass
        openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_port 5672
        openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_use_ssl false
        openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_virtual_host $brokervhost
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

chown -R heat.heat /var/log/heat
heat-manage db_sync
chown -R heat.heat /etc/heat /var/log/heat

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



