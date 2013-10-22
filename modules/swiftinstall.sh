#!/bin/bash
#
# Instalador desatendido para Openstack Havana sobre CENTOS
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@gmail.com
# Octubre del 2013
#
# Script de instalacion y preparacion de swift
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

if [ -f /etc/openstack-control-script-config/swift-installed ]
then
	echo ""
	echo "Este módulo ya fue ejecutado de manera exitosa - saliendo"
	echo ""
	exit 0
fi

echo ""
echo "Preparando recurso de filesystems"
echo ""

if [ ! -d "/srv/node" ]
then
	rm -f /etc/openstack-control-script-config/swift
	echo ""
	echo "ALERTA !. No existe el recurso de discos para swift - Abortando el"
	echo "resto de la instalación de swift"
	echo "Corrija la situación y vuelva a intentar ejecutar el módulo de"
	echo "instalación de swift"
	echo "El resto de la instalación de OpenStack continuará de manera normal,"
	echo "pero sin swift"
	echo "Dormiré por 10 segundos para que lea este mensaje"
	echo ""
	sleep 10
	exit 0
fi

checkdevice=`mount|awk '{print $3}'|grep -c ^/srv/node/$swiftdevice$`

case $checkdevice in
1)
	echo ""
	echo "Punto de montaje /srv/node/$swiftdevice verificado"
	echo "continuando con la instalación"
	echo ""
	;;
0)
	rm -f /etc/openstack-control-script-config/swift
	rm -f /etc/openstack-control-script-config/swift-installed
	echo ""
	echo "ALERTA !. No existe el recurso de discos para swift - Abortando el"
	echo "resto de la instalación de swift"
	echo "Corrija la situación y vuelva a intentar ejecutar el módulo de"
	echo "instalación de swift"
	echo "El resto de la instalación de OpenStack continuará de manera normal,"
	echo "pero sin swift"
	echo "Dormiré por 10 segundos para que lea este mensaje"
	echo ""
	sleep 10
	echo ""
	exit 0
	;;
esac

if [ $cleanupdeviceatinstall == "yes" ]
then
	rm -rf /srv/node/$swiftdevice/accounts
	rm -rf /srv/node/$swiftdevice/containers
	rm -rf /srv/node/$swiftdevice/objects
	rm -rf /srv/node/$swiftdevice/tmp
fi

echo ""
echo "Instalando paquetes para Swift"

yum install -y openstack-swift-proxy \
	openstack-swift-object \
	openstack-swift-container \
	openstack-swift-account \
	openstack-utils \
	memcached

echo "Listo"
echo ""

cat ./libs/openstack-config > /usr/bin/openstack-config

source $keystone_admin_rc_file

iptables -A INPUT -p tcp -m multiport --dports 6000,6001,6002,873 -j ACCEPT
service iptables save

chown -R swift:swift /srv/node/
restorecon -R /srv

echo ""
echo "Configurando Swift"
echo ""

mkdir -p /var/lib/keystone-signing-swift
chown swift:swift /var/lib/keystone-signing-swift

openstack-config --set /etc/swift/swift.conf swift-hash swift_hash_path_suffix $(openssl rand -hex 10)
# Ya no se necesita ???... esperando confirmación...
# openstack-config --set /etc/swift/swift.conf swift-hash swift_hash_path_prefix $(openssl rand -hex 10)

swiftworkers=`grep processor.\*: /proc/cpuinfo |wc -l`

openstack-config --set /etc/swift/object-server.conf DEFAULT bind_ip $swifthost
openstack-config --set /etc/swift/object-server.conf DEFAULT workers $swiftworkers
openstack-config --set /etc/swift/account-server.conf DEFAULT bind_ip $swifthost
openstack-config --set /etc/swift/account-server.conf DEFAULT workers $swiftworkers
openstack-config --set /etc/swift/container-server.conf DEFAULT bind_ip $swifthost
openstack-config --set /etc/swift/container-server.conf DEFAULT workers $swiftworkers

service openstack-swift-account start
service openstack-swift-container start
service openstack-swift-object start

chkconfig openstack-swift-account on
chkconfig openstack-swift-container on
chkconfig openstack-swift-object on

openstack-config --set /etc/swift/proxy-server.conf DEFAULT bind_port 8080
openstack-config --set /etc/swift/proxy-server.conf DEFAULT workers $swiftworkers
openstack-config --set /etc/swift/proxy-server.conf "pipeline:main" pipeline "healthcheck cache authtoken keystoneauth proxy-server"
openstack-config --set /etc/swift/proxy-server.conf "app:proxy-server" use "egg:swift#proxy"
openstack-config --set /etc/swift/proxy-server.conf "app:proxy-server" allow_account_management true
openstack-config --set /etc/swift/proxy-server.conf "app:proxy-server" account_autocreate true
openstack-config --set /etc/swift/proxy-server.conf "filter:keystoneauth" use "egg:swift#keystoneauth"
openstack-config --set /etc/swift/proxy-server.conf "filter:keystoneauth" operator_roles "Member,admin,swiftoperator"
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" paste.filter_factory "keystoneclient.middleware.auth_token:filter_factory"
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" delay_auth_decision true
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" admin_token $SERVICE_TOKEN
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" auth_token $SERVICE_TOKEN
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" admin_user $swiftuser
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" admin_password $swiftpass
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" auth_host $keystonehost
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" auth_port 35357
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" auth_protocol http
openstack-config --set /etc/swift/proxy-server.conf "filter:authtoken" signing_dir /var/lib/keystone-signing-swift
openstack-config --set /etc/swift/proxy-server.conf "filter:cache" use "egg:swift#memcache"
openstack-config --set /etc/swift/proxy-server.conf "filter:catch_errors" use "egg:swift#catch_errors"
openstack-config --set /etc/swift/proxy-server.conf "filter:healthcheck" use "egg:swift#healthcheck"

mkdir -p /var/lib/keystone-signing-swift
chown -R swift:swift /var/lib/keystone-signing-swift



if [ $ceilometerinstall == "yes" ]
then
	openstack-config --set /etc/swift/proxy-server.conf filter:ceilometer use "egg:ceilometer#swift"
fi

service memcached start
service openstack-swift-proxy start


swift-ring-builder /etc/swift/object.builder create $partition_power $replica_count $partition_min_hours
swift-ring-builder /etc/swift/container.builder create $partition_power $replica_count $partition_min_hours
swift-ring-builder /etc/swift/account.builder create $partition_power $replica_count $partition_min_hours

swift-ring-builder /etc/swift/account.builder add z$swiftfirstzone-$swifthost:6002/$swiftdevice $partition_count
swift-ring-builder /etc/swift/container.builder add z$swiftfirstzone-$swifthost:6001/$swiftdevice $partition_count
swift-ring-builder /etc/swift/object.builder add z$swiftfirstzone-$swifthost:6000/$swiftdevice $partition_count

swift-ring-builder /etc/swift/account.builder rebalance
swift-ring-builder /etc/swift/container.builder rebalance
swift-ring-builder /etc/swift/object.builder rebalance

chown -R swift:swift /etc/swift


chkconfig memcached on
chkconfig openstack-swift-proxy on

sync
service openstack-swift-proxy stop
service openstack-swift-proxy start
sync

iptables -A INPUT -p tcp -m multiport --dports 8080 -j ACCEPT
service iptables save


testswift=`rpm -qi openstack-swift-proxy|grep -ci "is not installed"`
if [ $testswift == "1" ]
then
	echo ""
	echo "Falló la instalación de swift - abortando el resto de la instalación"
	echo ""
	rm -f /etc/openstack-control-script-config/swift
	rm -f /etc/openstack-control-script-config/swift-installed
	exit 0
else
	date > /etc/openstack-control-script-config/swift-installed
	date > /etc/openstack-control-script-config/swift
fi

echo ""
echo "Instalación básica de SWIFT terminada"
echo ""






