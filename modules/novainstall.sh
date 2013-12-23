#!/bin/bash
#
# Instalador desatendido para Openstack Havana sobre CENTOS
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# Octubre del 2013
#
# Script de instalacion y preparacion de Nova
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

if [ -f /etc/openstack-control-script-config/nova-installed ]
then
	echo ""
	echo "Este módulo ya fue ejecutado de manera exitosa - saliendo"
	echo ""
	exit 0
fi


echo ""
echo "Instalando paquetes para Nova"

if [ $nova_in_compute_node = "no" ]
then
	yum install -y openstack-nova-novncproxy \
		openstack-nova-compute \
		openstack-nova-common \
		openstack-nova-api \
		openstack-nova-console \
		openstack-nova-conductor \
		openstack-nova-scheduler \
		openstack-nova-cert \
		python-cinderclient \
		openstack-utils \
		openstack-selinux
else
	yum install -y openstack-nova-compute \
		openstack-nova-common \
		python-cinderclient \
		openstack-utils \
		openstack-selinux
fi

cat ./libs/openstack-config > /usr/bin/openstack-config

echo "Listo"
echo ""

# Verificamos si este servidor va a poder soportar KVM - Si no, mas adelante
# configuraremos NOVA para usar qemu en lugar de kvm
# Si esta variable da cero, habrá que configurar la máquina para QEMU.
kvm_possible=`grep -E 'svm|vmx' /proc/cpuinfo|uniq|wc -l`

source $keystone_admin_rc_file


echo ""
echo "Aplicando Reglas de IPTABLES"

iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 6080 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 6081 -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 5900:5999 -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 8773,8774,8775 -j ACCEPT
service iptables save
echo ""
echo "Listo"
echo ""

echo "Configurando NOVA"

if [ $nova_in_compute_node = "no" ]
then
	openstack-config --set /etc/nova/api-paste.ini filter:authtoken paste.filter_factory "keystoneclient.middleware.auth_token:filter_factory"
	openstack-config --set /etc/nova/api-paste.ini filter:authtoken auth_protocol http
	openstack-config --set /etc/nova/api-paste.ini filter:authtoken auth_host $keystonehost
	openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_tenant_name $keystoneservicestenant
	openstack-config --set /etc/nova/api-paste.ini filter:authtoken auth_port 35357
	openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_password $novapass
	openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_user $novauser
	openstack-config --set /etc/nova/api-paste.ini filter:authtoken auth_uri http://$keystonehost:5000/v2.0/
fi

openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host $keystonehost
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user $novauser
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $novapass
openstack-config --set /etc/nova/nova.conf keystone_authtoken signing_dir /tmp/keystone-signing-nova


#
# Configuración principal
#

openstack-config --set /etc/nova/nova.conf DEFAULT notification_driver nova.openstack.common.notifier.rpc_notifier
if [ $ceilometerinstall == "yes" ]
then
	openstack-config --set /etc/nova/nova.conf DEFAULT notification_driver ceilometer.compute.nova_notifier
        case $brokerflavor in
        "qpid")
                sed -r -i 's/ceilometer.compute.nova_notifier/ceilometer.compute.nova_notifier\nnotification_driver\ =\ nova.openstack.common.notifier.rpc_notifier/' /etc/nova/nova.conf
                ;;
        "rabbitmq")
		# Rabbit Notifier DEPRECADO !!
                sed -r -i 's/ceilometer.compute.nova_notifier/ceilometer.compute.nova_notifier\nnotification_driver\ =\ nova.openstack.common.notifier.rpc_notifier/' /etc/nova/nova.conf
                ;;
        esac
	openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit True
	openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
	openstack-config --set /etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
fi
openstack-config --set /etc/nova/nova.conf DEFAULT use_forwarded_for False
openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
openstack-config --set /etc/nova/nova.conf DEFAULT logdir /var/log/nova
openstack-config --set /etc/nova/nova.conf DEFAULT state_path /var/lib/nova
openstack-config --set /etc/nova/nova.conf DEFAULT lock_path /var/lib/nova/tmp
openstack-config --set /etc/nova/nova.conf DEFAULT volumes_dir /etc/nova/volumes
openstack-config --set /etc/nova/nova.conf DEFAULT dhcpbridge /usr/bin/nova-dhcpbridge
openstack-config --set /etc/nova/nova.conf DEFAULT dhcpbridge_flagfile /etc/nova/nova.conf
openstack-config --set /etc/nova/nova.conf DEFAULT force_dhcp_release True
openstack-config --set /etc/nova/nova.conf DEFAULT injected_network_template /usr/share/nova/interfaces.template
openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_nonblocking True
openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_inject_partition -1
openstack-config --set /etc/nova/nova.conf DEFAULT network_manager nova.network.manager.FlatDHCPManager
openstack-config --set /etc/nova/nova.conf DEFAULT iscsi_helper tgtadm

#
# Base de datos
#

case $dbflavor in
"mysql")
	openstack-config --set /etc/nova/nova.conf DEFAULT sql_connection mysql://$novadbuser:$novadbpass@$dbbackendhost:$mysqldbport/$novadbname
	;;
"postgres")
	openstack-config --set /etc/nova/nova.conf DEFAULT sql_connection postgresql://$novadbuser:$novadbpass@$dbbackendhost:$psqldbport/$novadbname
	;;
esac

#
# Sigue configuración principal
#

osapiworkers=`grep processor.\*: /proc/cpuinfo |wc -l`

openstack-config --set /etc/nova/nova.conf DEFAULT compute_driver libvirt.LibvirtDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT rootwrap_config /etc/nova/rootwrap.conf
openstack-config --set /etc/nova/nova.conf DEFAULT osapi_volume_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT verbose False
openstack-config --set /etc/nova/nova.conf DEFAULT ec2_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT service_down_time 60
openstack-config --set /etc/nova/nova.conf DEFAULT image_service nova.image.glance.GlanceImageService
openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_use_virtio_for_bridges True
openstack-config --set /etc/nova/nova.conf DEFAULT osapi_compute_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_metadata_proxy_shared_secret $metadata_shared_secret
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT osapi_compute_workers $osapiworkers
openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_vif_driver nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_region_name $endpointsregion
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT debug False
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $novahost
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_password $neutronpass
openstack-config --set /etc/nova/nova.conf DEFAULT api_paste_config /etc/nova/api-paste.ini
openstack-config --set /etc/nova/nova.conf DEFAULT glance_api_servers $glancehost:9292
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_tenant_name $keystoneservicestenant
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_host $novahost
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_auth_url "http://$keystonehost:35357/v2.0"
openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis "ec2,osapi_compute,metadata"
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_username $neutronuser
openstack-config --set /etc/nova/nova.conf DEFAULT service_neutron_metadata_proxy True
openstack-config --set /etc/nova/nova.conf DEFAULT volume_api_class nova.volume.cinder.API
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_url "http://$neutronhost:9696"
openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_type kvm
openstack-config --set /etc/nova/nova.conf DEFAULT instance_name_template $instance_name_template
openstack-config --set /etc/nova/nova.conf DEFAULT start_guests_on_host_boot $start_guests_on_host_boot
openstack-config --set /etc/nova/nova.conf DEFAULT resume_guests_state_on_host_boot $resume_guests_state_on_host_boot
openstack-config --set /etc/nova/nova.conf DEFAULT instance_name_template $instance_name_template
openstack-config --set /etc/nova/nova.conf DEFAULT allow_resize_to_same_host $allow_resize_to_same_host
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled True
openstack-config --set /etc/nova/nova.conf DEFAULT ram_allocation_ratio $ram_allocation_ratio
openstack-config --set /etc/nova/nova.conf DEFAULT cpu_allocation_ratio $cpu_allocation_ratio
openstack-config --set /etc/nova/nova.conf DEFAULT connection_type libvirt
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_host 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $novahost
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url "http://$vncserver_controller_address:6080/vnc_auto.html"
openstack-config --set /etc/nova/nova.conf DEFAULT scheduler_default_filters "RetryFilter,AvailabilityZoneFilter,RamFilter,ComputeFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,CoreFilter"
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_port 6080
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen $novahost
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_keymap $vnc_keymap
openstack-config --set /etc/nova/nova.conf DEFAULT force_config_drive true
openstack-config --set /etc/nova/nova.conf DEFAULT config_drive_format iso9660
openstack-config --set /etc/nova/nova.conf DEFAULT config_drive_cdrom true
openstack-config --set /etc/nova/nova.conf DEFAULT config_drive_inject_password True
openstack-config --set /etc/nova/nova.conf DEFAULT mkisofs_cmd genisoimage
openstack-config --set /etc/nova/nova.conf DEFAULT dhcp_domain $dhcp_domain

# Mas opciones nuevas para Nova
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_ovs_integration_bridge $integration_bridge
openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_ovs_bridge $integration_bridge
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_ovs_bridge $integration_bridge
openstack-config --set /etc/nova/nova.conf DEFAULT dhcp_options_enabled True

case $brokerflavor in
"qpid")
	openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend nova.openstack.common.rpc.impl_qpid
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_reconnect_interval_min 0
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_username $brokeruser
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_reconnect True
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_tcp_nodelay True
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_protocol tcp
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname $messagebrokerhost
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_password $brokerpass
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_port 5672
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_reconnect_limit 0
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_reconnect_interval 0
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_reconnect_timeout 0
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_heartbeat 60
	openstack-config --set /etc/nova/nova.conf DEFAULT qpid_reconnect_interval_max 0
	;;

"rabbitmq")
	openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend nova.openstack.common.rpc.impl_kombu
	openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_host $messagebrokerhost
	openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_userid $brokeruser
	openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_password $brokerpass
	openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_port 5672
	openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_use_ssl false
	openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_virtual_host $brokervhost
	;;
esac

sync
sleep 5
sync

if [ $kvm_possible == "0" ]
then
	echo ""
	echo "ALERTA !!! - Este servidor NO SOPORTA KVM - Se reconfigurará NOVA"
	echo "para usar virtualización por software vía QEMU"
	echo "El rendimiento será pobre"
	echo ""
	source $keystone_admin_rc_file
	openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_type qemu
	setsebool -P virt_use_execmem on
	ln -s -f /usr/libexec/qemu-kvm /usr/bin/qemu-system-x86_64
	service libvirtd restart
	echo ""
else
	openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_cpu_mode $libvirt_cpu_mode
fi

sync
sleep 5
sync

if [ $nova_in_compute_node = "no" ]
then
	su nova -s /bin/sh -c "nova-manage db sync"
fi

sync
sleep 5
sync

echo "Listo"

echo "Activando Servicios de Nova"

if [ $nova_in_compute_node = "no" ]
then
	service openstack-nova-api start
	chkconfig openstack-nova-api on

	service openstack-nova-cert start
	chkconfig openstack-nova-cert on

	service openstack-nova-scheduler start
	chkconfig openstack-nova-scheduler on

	service openstack-nova-conductor start
	chkconfig openstack-nova-conductor on

	service openstack-nova-consoleauth start
	chkconfig openstack-nova-consoleauth on

	service openstack-nova-novncproxy start
	chkconfig openstack-nova-novncproxy on

	if [ $nova_without_compute = "no" ]
	then
		service openstack-nova-compute start
		chkconfig openstack-nova-compute on
	else
		service openstack-nova-compute stop
		chkconfig openstack-nova-compute off		
	fi
else
	service openstack-nova-compute start
	chkconfig openstack-nova-compute on
fi

echo ""
echo "Listo"

echo ""
echo "Voy a dormir por 10 segundos - Me encanta dormir y hacerles perder tiempo"
echo ""

sync
sleep 10
sync

service iptables save

echo ""
echo "Ya me desperté... sonaría el despertador ??"
echo ""

if [ $nova_in_compute_node = "no" ]
then
	if [ $vm_default_access == "yes" ]
	then
		echo ""
		echo "Creando accesos de seguridad para las VM's"
		echo "Puertos: ssh e ICMP"
		echo ""
		source $keystone_admin_rc_file
		nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
		nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
		echo "Listo"
		echo ""
	fi

	for vmport in $vm_extra_ports_tcp
	do
		echo ""
		echo "Creando acceso de seguridad para el puerto $vmport tcp"
		source $keystone_admin_rc_file
		nova secgroup-add-rule default tcp $vmport $vmport 0.0.0.0/0
	done

	for vmport in $vm_extra_ports_udp
	do
		echo ""
		echo "Creando acceso de seguridad para el puerto $vmport udp"
		source $keystone_admin_rc_file
		nova secgroup-add-rule default udp $vmport $vmport 0.0.0.0/0
	done
fi

testnova=`rpm -qi openstack-nova-compute|grep -ci "is not installed"`
if [ $testnova == "1" ]
then
	echo ""
	echo "Falló la instalación de nova - abortando el resto de la instalación"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/nova-installed
	date > /etc/openstack-control-script-config/nova
	if [ $nova_in_compute_node = "no" ]
	then
		date > /etc/openstack-control-script-config/nova-full-installed
	fi
	if [ $nova_without_compute = "yes" ]
	then
		if [ $nova_in_compute_node = "no" ]
		then
			date > /etc/openstack-control-script-config/nova-without-compute
		fi
	fi
fi

echo ""
echo "Nova Instalado y Configurado"
echo ""








