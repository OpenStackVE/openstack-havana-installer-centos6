#!/bin/bash
#
# Instalador desatendido para Openstack Havana sobre CENTOS
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# Octubre del 2013
#
# Script de instalacion y preparacion de neutron
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

if [ -f /etc/openstack-control-script-config/neutron-installed ]
then
	echo ""
	echo "Este módulo ya fue ejecutado de manera exitosa - saliendo"
	echo ""
	exit 0
fi


echo "Instalando Paquetes para NEUTRON"

yum install -y openstack-neutron openstack-neutron-openvswitch openstack-utils openstack-selinux haproxy

cat ./libs/openstack-config > /usr/bin/openstack-config

echo ""
echo "Listo"

echo ""
echo "Actualizando versión de dnsmasq"
rpm -Uvh ./libs/dnsmasq-2.65-1.el6.rfx.x86_64.rpm

echo "Listo"

sleep 5
cat /etc/dnsmasq.conf > $dnsmasq_config_file
mkdir -p /etc/dnsmasq-neutron.d
echo "conf-dir=/etc/dnsmasq-neutron.d" >> $dnsmasq_config_file
echo "# Extra options for Neutron-DNSMASQ" > /etc/dnsmasq-neutron.d/neutron-dnsmasq-extra.conf
echo "# Samples:" >> /etc/dnsmasq-neutron.d/neutron-dnsmasq-extra.conf
echo "# dhcp-option=option:ntp-server,192.168.1.1" >> /etc/dnsmasq-neutron.d/neutron-dnsmasq-extra.conf
echo "# dhcp-option = tag:tag0, option:ntp-server, 192.168.1.1" >> /etc/dnsmasq-neutron.d/neutron-dnsmasq-extra.conf
echo "# dhcp-option = tag:tag1, option:ntp-server, 192.168.1.1" >> /etc/dnsmasq-neutron.d/neutron-dnsmasq-extra.conf
echo "# expand-hosts"  >> /etc/dnsmasq-neutron.d/neutron-dnsmasq-extra.conf
echo "# domain=dominio-interno-uno.home,192.168.1.0/24"  >> /etc/dnsmasq-neutron.d/neutron-dnsmasq-extra.conf
echo "# domain=dominio-interno-dos.home,192.168.100.0/24"  >> /etc/dnsmasq-neutron.d/neutron-dnsmasq-extra.conf
sync
sleep 5

echo "Listo"
echo ""

source $keystone_admin_rc_file

echo ""
echo "Aplicando Reglas de IPTABLES"
iptables -A INPUT -p tcp -m multiport --dports 9696 -j ACCEPT
iptables -A INPUT -p udp -m state --state NEW -m udp --dport 67 -j ACCEPT
iptables -A INPUT -p udp -m state --state NEW -m udp --dport 68 -j ACCEPT
iptables -t mangle -A POSTROUTING -p udp -m udp --dport 67 -j CHECKSUM --checksum-fill
iptables -t mangle -A POSTROUTING -p udp -m udp --dport 68 -j CHECKSUM --checksum-fill
service iptables save
echo "Listo"

echo ""
echo "Configurando Neutron"

sync
sleep 5
sync

openstack-config --set /etc/neutron/neutron.conf DEFAULT debug False
openstack-config --set /etc/neutron/neutron.conf DEFAULT verbose False
openstack-config --set /etc/neutron/neutron.conf DEFAULT log_dir /var/log/neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT bind_host 0.0.0.0
openstack-config --set /etc/neutron/neutron.conf DEFAULT bind_port 9696
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin  neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf DEFAULT base_mac "$basemacspec"
openstack-config --set /etc/neutron/neutron.conf DEFAULT base_mac "$basemacspec"
openstack-config --set /etc/neutron/neutron.conf DEFAULT mac_generation_retries 16
openstack-config --set /etc/neutron/neutron.conf DEFAULT dhcp_lease_duration 120
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_bulk True
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips False
openstack-config --set /etc/neutron/neutron.conf DEFAULT control_exchange neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier
openstack-config --set /etc/neutron/neutron.conf DEFAULT default_notification_level INFO
openstack-config --set /etc/neutron/neutron.conf DEFAULT notification_topics notifications
openstack-config --set /etc/neutron/neutron.conf DEFAULT state_path /var/lib/neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT lock_path /var/lib/neutron/lock

openstack-config --set /etc/neutron/neutron.conf DEFAULT api_paste_config api-paste.ini


case $brokerflavor in
"qpid")
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend neutron.openstack.common.rpc.impl_qpid
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_hostname $messagebrokerhost
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_port 5672
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_username $brokeruser
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_password $brokerpass
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_heartbeat 60
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_protocol tcp
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_tcp_nodelay True
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_interval 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_interval_min 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_interval_max 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_timeout 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_limit 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect True
	;;

"rabbitmq")
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend neutron.openstack.common.rpc.impl_kombu
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_host $messagebrokerhost
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_password $brokerpass
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_userid $brokeruser
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_port 5672
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_use_ssl false
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_virtual_host $brokervhost
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_max_retries 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_retry_interval 1
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_ha_queues false
	;;
esac

openstack-config --set /etc/neutron/neutron.conf agent root_helper "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"

openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_host $keystonehost
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user $neutronuser
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password $neutronpass
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_protocol http

# Nuevo token de configuracion para el LBaaS
openstack-config --set /etc/neutron/neutron.conf service_providers service_provider LOADBALANCER:Haproxy:neutron.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default

sync
sleep 2
sync

openstack-config --set /etc/neutron/l3_agent.ini DEFAULT debug False
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT ovs_use_veth True
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT handle_internal_only_routers True
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT send_arp_for_ha 3
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT periodic_interval 40
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT periodic_fuzzy_delay 5
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge ""
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT metadata_port 9697
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT enable_metadata_proxy True

sync
sleep 2
sync

openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT debug False
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT resync_interval 30
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT ovs_use_veth True
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT state_path /var/lib/neutron
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file $dnsmasq_config_file
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_domain $dhcp_domain
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT root_helper "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"

sync
sleep 2
sync

openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini DATABASE sql_max_retries 10
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini DATABASE reconnect_interval 2

case $dbflavor in
"mysql")
	openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini DATABASE sql_connection mysql://$neutrondbuser:$neutrondbpass@$dbbackendhost:$mysqldbport/$neutrondbname
	;;
"postgres")
	openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini DATABASE sql_connection postgresql://$neutrondbuser:$neutrondbpass@$dbbackendhost:$psqldbport/$neutrondbname
	;;
esac

openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini DATABASE sql_idle_timeout 3600


openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini OVS integration_bridge $integration_bridge
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini OVS bridge_mappings $bridge_mappings
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini OVS enable_tunneling False
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini OVS network_vlan_ranges $network_vlan_ranges
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini OVS tenant_network_type vlan

openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini AGENT polling_interval 2

openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini SECURITYGROUP firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

sync
sleep 2
sync

ln -f -s /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini /etc/neutron/plugin.ini

openstack-config --set /etc/neutron/api-paste.ini filter:authtoken paste.filter_factory "keystoneclient.middleware.auth_token:filter_factory"
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken auth_protocol http
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken auth_host $keystonehost
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken admin_user $neutronuser
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken admin_password $neutronpass
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken auth_port 35357
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken auth_uri http://$keystonehost:5000/v2.0/

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT debug False
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url "http://$keystonehost:35357/v2.0"
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_region $endpointsregion
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user $neutronuser
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password $neutronpass
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $novahost
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_port 8775
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $metadata_shared_secret

sync
sleep 2
sync

openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT periodic_interval 10
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT ovs_use_veth True
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT device_driver  neutron.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT use_namespaces True
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT user_group neutron

sync
sleep 2
sync

mkdir -p /etc/neutron/plugins/services/agent_loadbalancer
cp -v /etc/neutron/lbaas_agent.ini /etc/neutron/plugins/services/agent_loadbalancer/
chown root.neutron /etc/neutron/plugins/services/agent_loadbalancer/lbaas_agent.ini
sync

neutron-dhcp-setup --plugin openvswitch --qhost $neutronhost
neutron-l3-setup --plugin openvswitch --qhost $neutronhost

sync
sleep 5
sync

case $brokerflavor in
"qpid")
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend neutron.openstack.common.rpc.impl_qpid
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_hostname $messagebrokerhost
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_port 5672
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_username $brokeruser
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_password $brokerpass
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_heartbeat 60
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_protocol tcp
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_tcp_nodelay True
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_interval 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_interval_min 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_interval_max 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_timeout 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect_limit 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_reconnect True
	;;

"rabbitmq")
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend neutron.openstack.common.rpc.impl_kombu
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_host $messagebrokerhost
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_password $brokerpass
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_userid $brokeruser
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_port 5672
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_use_ssl false
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_virtual_host $brokervhost
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_max_retries 0
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_retry_interval 1
	openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_ha_queues false
	;;
esac

sync
sleep 2
sync

echo ""
echo "Listo"
echo ""

echo "Activando Servicios de Neutron"

if [ $neutron_in_compute_node == "yes" ]
then
	chkconfig neutron-ovs-cleanup on

	service neutron-server stop
	chkconfig neutron-server off

	service neutron-dhcp-agent stop
	chkconfig neutron-dhcp-agent off

	service neutron-l3-agent stop
	chkconfig neutron-l3-agent off

	service neutron-lbaas-agent stop
	chkconfig neutron-lbaas-agent off

	service neutron-metadata-agent stop
	chkconfig neutron-metadata-agent off

	service neutron-openvswitch-agent start
	chkconfig neutron-openvswitch-agent on
else 
	chkconfig neutron-ovs-cleanup on

	service neutron-server start
	chkconfig neutron-server on

	service neutron-dhcp-agent start
	chkconfig neutron-dhcp-agent on

	service neutron-l3-agent start
	chkconfig neutron-l3-agent on

	service neutron-lbaas-agent start
	chkconfig neutron-lbaas-agent on

	service neutron-metadata-agent start
	chkconfig neutron-metadata-agent on

	service neutron-openvswitch-agent start
	chkconfig neutron-openvswitch-agent on
fi

echo "Listo"

echo ""
echo "Voy a dormir por 10 segundos"
sync
sleep 10
sync
echo ""
echo "Ya desperté - continuando"
echo ""

if [ $neutron_in_compute_node == "no" ]
then
	if [ $network_create == "yes" ]
	then
		source $keystone_admin_rc_file

		for MyNet in $network_create_list
		do
			echo ""
			echo "Creando red $MyNet"
			neutron net-create $MyNet --shared --provider:network_type flat --provider:physical_network $MyNet
			echo ""
			echo "Red $MyNet creada !"
			echo ""
		done
	fi
fi

echo ""
echo "Voy a dormir otros 10 segundos - soy un dormilon"
echo ""
sync
sleep 10
sync
service iptables save

echo "ya desperté"

testneutron=`rpm -qi openstack-neutron|grep -ci "is not installed"`
if [ $testneutron == "1" ]
then
	echo ""
	echo "Falló la instalación de neutron - abortando el resto de la instalación"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/neutron-installed
	date > /etc/openstack-control-script-config/neutron
	if [ $neutron_in_compute_node == "no" ]
	then
		date > /etc/openstack-control-script-config/neutron-full-installed
	fi
fi

echo ""
echo "Servicio Neutron Configurado y operativo"
echo ""

