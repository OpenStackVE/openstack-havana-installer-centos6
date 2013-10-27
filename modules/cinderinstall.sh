#!/bin/bash
#
# Instalador desatendido para Openstack Havana sobre CENTOS
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# Octubre del 2013
#
# Script de instalacion y preparacion de cinder
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

if [ -f /etc/openstack-control-script-config/cinder-installed ]
then
	echo ""
	echo "Este módulo ya fue ejecutado de manera exitosa - saliendo"
	echo ""
	exit 0
fi


echo "Instalando paquetes para Cinder"

yum -y install openstack-cinder openstack-utils openstack-selinux

cat ./libs/openstack-config > /usr/bin/openstack-config

source $keystone_admin_rc_file

echo "Listo"

echo ""
echo "Configurando Cinder"

sync
sleep 5
sync

openstack-config --set /etc/cinder/api-paste.ini filter:authtoken paste.filter_factory  keystoneclient.middleware.auth_token:filter_factory
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken service_protocol http
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken service_host $keystonehost
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken service_port 5000
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken auth_protocol http
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken auth_host $keystonehost
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken admin_user $cinderuser
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken admin_password $cinderpass
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken auth_port 35357
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken auth_uri http://$keystonehost:5000/v2.0/


openstack-config --set /etc/cinder/cinder.conf DEFAULT osapi_volume_listen 0.0.0.0
openstack-config --set /etc/cinder/cinder.conf DEFAULT api_paste_config /etc/cinder/api-paste.ini
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host $glancehost
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf DEFAULT debug False
openstack-config --set /etc/cinder/cinder.conf DEFAULT verbose False


case $brokerflavor in
"qpid")
	openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend cinder.openstack.common.rpc.impl_qpid
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_hostname $messagebrokerhost
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_username $brokeruser
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_password $brokerpass
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_reconnect_limit 0
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_reconnect true
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_reconnect_interval_min 0
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_reconnect_interval_max 0
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_heartbeat 60
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_protocol tcp
	openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_tcp_nodelay True
	;;

"rabbitmq")
	openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend cinder.openstack.common.rpc.impl_kombu
	openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_host $messagebrokerhost
	openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_port 5672
	openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_use_ssl false
	openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_userid $brokeruser
	openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_password $brokerpass
	openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_virtual_host $brokervhost
	;;
esac

openstack-config --set /etc/cinder/cinder.conf DEFAULT iscsi_helper tgtadm
openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_group cinder-volumes
openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.lvm.LVMISCSIDriver
openstack-config --set /etc/cinder/cinder.conf DEFAULT logdir /var/log/cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT state_path /var/lib/cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT lock_path /var/lib/cinder/tmp
openstack-config --set /etc/cinder/cinder.conf DEFAULT volumes_dir /etc/cinder/volumes
openstack-config --set /etc/cinder/cinder.conf DEFAULT rootwrap_config /etc/cinder/rootwrap.conf
openstack-config --set /etc/cinder/cinder.conf DEFAULT iscsi_ip_address $cinder_iscsi_ip_address


case $dbflavor in
"mysql")
	openstack-config --set /etc/cinder/cinder.conf DEFAULT sql_connection mysql://$cinderdbuser:$cinderdbpass@$dbbackendhost:$mysqldbport/$cinderdbname
	;;
"postgres")
	openstack-config --set /etc/cinder/cinder.conf DEFAULT sql_connection postgresql://$cinderdbuser:$cinderdbpass@$dbbackendhost:$psqldbport/$cinderdbname
	;;
esac

openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_host $keystonehost
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_user $cinderuser
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_password $cinderpass
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken signing_dirname /tmp/keystone-signing-cinder

if [ $ceilometerinstall == "yes" ]
then
	openstack-config --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
	case $brokerflavor in
	"qpid")
		openstack-config --set /etc/cinder/cinder.conf DEFAULT notification_driver cinder.openstack.common.notifier.rpc_notifier
		;;
	"rabbitmq")
		# ATENCION: Rabbit Notifier DEPRECADO !!
		openstack-config --set /etc/cinder/cinder.conf DEFAULT notification_driver cinder.openstack.common.notifier.rpc_notifier
		;;
	esac
fi

su cinder -s /bin/sh -c "cinder-manage db sync"

echo "include /etc/cinder/volumes/*" >> /etc/tgt/targets.conf

echo ""
echo "Levantando servicios de Cinder"

service openstack-cinder-api start
chkconfig openstack-cinder-api on
service openstack-cinder-scheduler start
chkconfig openstack-cinder-scheduler on
service openstack-cinder-volume start
service tgtd start
chkconfig openstack-cinder-volume on
chkconfig tgtd on

yum -y install python-cinderclient

echo "Listo"

echo ""
echo "Aplicando reglas de IPTABLES"

iptables -A INPUT -p tcp -m multiport --dports 3260,8776 -j ACCEPT
service iptables save

testcinder=`rpm -qi openstack-cinder|grep -ci "is not installed"`
if [ $testcinder == "1" ]
then
	echo ""
	echo "Falló la instalación de cinder - abortando el resto de la instalación"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/cinder-installed
	date > /etc/openstack-control-script-config/cinder
fi

echo "Listo"

echo ""
echo "Cinder Instalado"
echo ""



