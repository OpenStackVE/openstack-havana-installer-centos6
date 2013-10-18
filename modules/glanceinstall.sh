#!/bin/bash
#
# Instalador desatendido para Openstack Havana sobre CENTOS
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# Octubre del 2013
#
# Script de instalacion y preparacion de glance
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

if [ -f /etc/openstack-control-script-config/glance-installed ]
then
	echo ""
	echo "Este módulo ya fue ejecutado de manera exitosa - saliendo"
	echo ""
	exit 0
fi


echo ""
echo "Instalando paquetes para Glance"

yum install -y openstack-glance openstack-utils openstack-selinux

cat ./libs/openstack-config > /usr/bin/openstack-config

tar -xzvf ./libs/sqlalchemy-migrate-0.7.2.tar.gz -C /usr/local/src/
cd /usr/local/src/sqlalchemy-migrate-0.7.2/
python ./setup.py install
cd -

echo "Listo"
echo ""

source $keystone_admin_rc_file

echo ""
echo "Configurando Glance"

sync
sleep 5
sync

openstack-config --set /etc/glance/glance-api.conf DEFAULT verbose False
openstack-config --set /etc/glance/glance-api.conf DEFAULT debug False
openstack-config --set /etc/glance/glance-api.conf DEFAULT default_store file
openstack-config --set /etc/glance/glance-api.conf DEFAULT bind_host 0.0.0.0
openstack-config --set /etc/glance/glance-api.conf DEFAULT bind_port 9292
openstack-config --set /etc/glance/glance-api.conf DEFAULT log_file /var/log/glance/api.log
openstack-config --set /etc/glance/glance-api.conf DEFAULT backlog 4096


case $dbflavor in
"mysql")
	openstack-config --set /etc/glance/glance-api.conf DEFAULT sql_connection mysql://$glancedbuser:$glancedbpass@$dbbackendhost:$mysqldbport/$glancedbname
	openstack-config --set /etc/glance/glance-registry.conf DEFAULT sql_connection mysql://$glancedbuser:$glancedbpass@$dbbackendhost:$mysqldbport/$glancedbname
	;;
"postgres")
	openstack-config --set /etc/glance/glance-api.conf DEFAULT sql_connection postgresql://$glancedbuser:$glancedbpass@$dbbackendhost:$psqldbport/$glancedbname
	openstack-config --set /etc/glance/glance-registry.conf DEFAULT sql_connection postgresql://$glancedbuser:$glancedbpass@$dbbackendhost:$psqldbport/$glancedbname
	;;
esac

glanceworkers=`grep processor.\*: /proc/cpuinfo |wc -l`

openstack-config --set /etc/glance/glance-api.conf DEFAULT sql_idle_timeout 3600
openstack-config --set /etc/glance/glance-api.conf DEFAULT workers $glanceworkers
openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_host 0.0.0.0
openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_port 9191
openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_client_protocol http
openstack-config --set /etc/glance/glance-api.conf DEFAULT filesystem_store_datadir /var/lib/glance/images/
openstack-config --set /etc/glance/glance-api.conf DEFAULT delayed_delete False
openstack-config --set /etc/glance/glance-api.conf DEFAULT scrub_time 43200


case $brokerflavor in
"qpid")
	openstack-config --set /etc/glance/glance-api.conf DEFAULT notifier_strategy qpid
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_notification_exchange glance
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_notification_topic notifications
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_host $messagebrokerhost
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_port 5672
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_username $brokeruser
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_password $brokerpass
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_reconnect_timeout 0
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_reconnect_limit 0
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_reconnect_interval_min 0
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_reconnect_interval_max 0
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_reconnect_interval 0
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_heartbeat 5
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_protocol tcp
	openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_tcp_nodelay True
	;;

"rabbitmq")
	openstack-config --set /etc/glance/glance-api.conf DEFAULT notifier_strategy rabbit
	openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_host $messagebrokerhost
	openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_port 5672
	openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_use_ssl false
	openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_userid $brokeruser
	openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_password $brokerpass
	openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_virtual_host $brokervhost
	openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_notification_exchange glance
	openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_notification_topic notifications
	openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_durable_queues False
	;;
esac

openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_host $keystonehost
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user $glanceuser
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password $glancepass
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$keystonehost:5000/v2.0/

openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone


openstack-config --set /etc/glance/glance-registry.conf DEFAULT verbose False
openstack-config --set /etc/glance/glance-registry.conf DEFAULT debug False
openstack-config --set /etc/glance/glance-registry.conf DEFAULT bind_host 0.0.0.0
openstack-config --set /etc/glance/glance-registry.conf DEFAULT bind_port 9191
openstack-config --set /etc/glance/glance-registry.conf DEFAULT log_file /var/log/glance/registry.log
openstack-config --set /etc/glance/glance-registry.conf DEFAULT backlog 4096



openstack-config --set /etc/glance/glance-registry.conf DEFAULT sql_idle_timeout 3600
openstack-config --set /etc/glance/glance-registry.conf DEFAULT api_limit_max 1000
openstack-config --set /etc/glance/glance-registry.conf DEFAULT limit_param_default 25

openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_host $keystonehost
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user $glanceuser
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password $glancepass
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$keystonehost:5000/v2.0/

openstack-config --set /etc/glance/glance-cache.conf DEFAULT verbose False
openstack-config --set /etc/glance/glance-cache.conf DEFAULT debug False
openstack-config --set /etc/glance/glance-cache.conf DEFAULT log_file /var/log/glance/image-cache.log
openstack-config --set /etc/glance/glance-cache.conf DEFAULT image_cache_dir /var/lib/glance/image-cache/
openstack-config --set /etc/glance/glance-cache.conf DEFAULT image_cache_stall_time 86400
openstack-config --set /etc/glance/glance-cache.conf DEFAULT image_cache_invalid_entry_grace_period 3600
openstack-config --set /etc/glance/glance-cache.conf DEFAULT image_cache_max_size 10737418240
openstack-config --set /etc/glance/glance-cache.conf DEFAULT registry_host 0.0.0.0
openstack-config --set /etc/glance/glance-cache.conf DEFAULT registry_port 9191
openstack-config --set /etc/glance/glance-cache.conf DEFAULT admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/glance/glance-cache.conf DEFAULT admin_user $glanceuser
openstack-config --set /etc/glance/glance-cache.conf DEFAULT filesystem_store_datadir /var/lib/glance/images/

mkdir -p /var/lib/glance/image-cache/
chown -R glance.glance /var/lib/glance/image-cache

echo "Listo"

su glance -s /bin/sh -c "glance-manage db_sync"

sync
sleep 5
sync

echo ""
echo "Aplicando reglas de IPTABLES"
iptables -A INPUT -p tcp -m multiport --dports 9292 -j ACCEPT
service iptables save
echo "Listo"
echo ""

echo "Activando Servicios de GLANCE"

service openstack-glance-registry start
service openstack-glance-api start
chkconfig openstack-glance-registry on
chkconfig openstack-glance-api on



if [ $glance_use_swift == "yes" ]
then
	if [ -f /etc/openstack-control-script-config/swift-installed ]
	then
		openstack-config --set /etc/glance/glance-api.conf DEFAULT default_store swift
		openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_auth_address http://$keystonehost:5000/v2.0/
		openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_user $keystoneservicestenant:$swiftuser
		openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_key $swiftpass
		openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_create_container_on_put True
		openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_auth_version 2
		openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_container glance
		openstack-config --set /etc/glance/glance-cache.conf DEFAULT default_store swift
		openstack-config --set /etc/glance/glance-cache.conf DEFAULT swift_store_auth_address http://$keystonehost:5000/v2.0/
		openstack-config --set /etc/glance/glance-cache.conf DEFAULT swift_store_user $keystoneservicestenant:$swiftuser
		openstack-config --set /etc/glance/glance-cache.conf DEFAULT swift_store_key $swiftpass
		openstack-config --set /etc/glance/glance-cache.conf DEFAULT swift_store_create_container_on_put True
		openstack-config --set /etc/glance/glance-cache.conf DEFAULT swift_store_auth_version 2
		openstack-config --set /etc/glance/glance-cache.conf DEFAULT swift_store_container glance
		service openstack-glance-registry restart
		service openstack-glance-api restart
	fi
fi

testglance=`rpm -qi openstack-glance|grep -ci "is not installed"`
if [ $testglance == "1" ]
then
	echo ""
	echo "Falló la instalación de glance - abortando el resto de la instalación"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/glance-installed
	date > /etc/openstack-control-script-config/glance
fi

echo ""
echo "Glance Instalado"
echo ""

if [ $glancecirroscreate == "yes" ]
then
	echo ""
	echo "Creando imágenes Cirros para pruebas de OpenStack"
	echo ""
	source $keystone_admin_rc_file

	sync
	sleep 10
	sync

	glance image-create --name="Cirros 0.3.1 32 bits" \
		--disk-format=qcow2 \
		--container-format bare < ./libs/cirros/cirros-0.3.1-i386-disk.img

	sync
	sleep 10
	sync

	glance image-create --name="Cirros 0.3.1 64 bits" \
		--disk-format=qcow2 \
		--container-format bare < ./libs/cirros/cirros-0.3.1-x86_64-disk.img

	sync
	sleep 5
	sync

	glance image-list

	echo ""
	echo "Imágenes de cirros 0.3.1 para 32 y 64 bits creadas"
	echo ""
fi


