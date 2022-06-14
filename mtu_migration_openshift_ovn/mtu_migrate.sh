#!/bin/bash
# $1 arguement expects desired_cluster_network_MTU you want to migrate to
# $2 is optional for vsphere
# $3 is optional for ipsec
# your local env expects coreos/butane utility to be downloaded from curl https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane --output butane

desired_cluster_nw_mtu=$(($1))
ipsec=$3
vsphere=$2

function wait_mcp_co {
	oc wait mcp --all --for=condition=UPDATED=True --timeout=900s
	oc wait co --all --for=condition=PROGRESSING=false --timeout=900s
	oc wait co --all --for=condition=AVAILABLE=true --timeout=900s
	oc wait co --all --for=condition=DEGRADED=false --timeout=900s
}

function pre_CNO_patch {

        #Copy default NM template from master/worker locally and modify them as per our requirements above
	#Change MTU to desired_cluster_nw_MTU +100 or 146 for ipsec, reduce autoconnect-priority to less than 100 and change id name to something else like ovn-if-test
	master=`oc get nodes -l node-role.kubernetes.io/master -o=jsonpath={.items[0].metadata.name}`
	
	if [[ $vsphere == "vsphere" ]] 
        then 
	   echo -e "Platform ${RED}is${NC} Vsphere"	   
	   oc debug node/$master -- chroot /host cat /etc/NetworkManager/system-connections/br-ex.nmconnection > config.nmconnection
	else
	   oc debug node/$master -- chroot /host cat /etc/NetworkManager/system-connections/ovs-if-phys0.nmconnection > config.nmconnection
	fi

	#Find current machine MTU
	current_machine_mtu=`cat config.nmconnection | grep "mtu=" |sed 's/^mtu=//'`
	echo "current machine MTU is $current_machine_mtu"

	#Find current cluster MTU which is nothing but overlay_from_MTU
	current_cluster_nw_mtu=$((`oc describe network.config.openshift.io | grep "Cluster Network MTU" | sed 's/^.*:  //'`))
	echo "current cluster network MTU is $current_cluster_nw_mtu"
	current_cluster_nw_mtu=$(($current_cluster_nw_mtu))

	#For OVN IPsec new machine mtu will be 146 bytes more than cluster_nw_mtu to acocomodate ovn+46(for ipsec)  headers
	if [[ $ipsec == "ipsec" ]] 
        then 
           new_machine_mtu=$(($desired_cluster_nw_mtu+146))
	   echo "New IPsec Machine MTU is $new_machine_mtu"
        else
           new_machine_mtu=$(($desired_cluster_nw_mtu+100))
	   echo "New Machine MTU is $new_machine_mtu"
	fi
	echo "And you want to migrate cluster network MTU to $desired_cluster_nw_mtu ?"
	read -p "Do you want to proceed? (yes/no) " yn
	case $yn in 
		yes ) echo ok, we will proceed;;
		no ) echo exiting...;
			exit;;
		* ) echo invalid response;
			exit 1;;
	esac

	echo Proceeding....

	#nmconnection template file changes
	sed -i 's/autoconnect-priority=100/autoconnect-priority=99/g' config.nmconnection
	sed -i 's/id=.*/id=ovs-if-test/g' config.nmconnection
	sed -i "s/mtu=.*/mtu=$new_machine_mtu/g" config.nmconnection
	sed -i '/uuid/d' config.nmconnection

	#Generating machine config manifests from bu files to be used later
	for manifest in control-plane-interface worker-interface; do butane --files-dir . $manifest.bu > $manifest.yaml; done

	#Patching CNO
	patch="oc patch Network.operator.openshift.io cluster --type=merge -p='{\"spec\":{\"migration\":{\"mtu\":{\"network\":{\"from\":$((current_cluster_nw_mtu)),\"to\":$((desired_cluster_nw_mtu))},\"machine\":{\"to\":$new_machine_mtu}}}}}'"
	echo $patch
	eval $patch
}

# If we lose the network connection post pre_CNO_patch we can call below function later after commenting "pre_CNO_patch" function call in main
function post_CNO_patch {

	#Wait MC and COto rollout properly
	wait_mcp_co

	#Generating new manifests based on 
	for manifest in control-plane-interface worker-interface; do oc create -f $manifest.yaml;done

	#Wait MC and CO to rollout properly
	wait_mcp_co

	#Patch CNO with desired_cluster_nw_mtu 
	patch="oc patch Network.operator.openshift.io cluster --type=merge -p='{\"spec\":{\"migration\":null,\"defaultNetwork\":{\"ovnKubernetesConfig\":{\"mtu\":$desired_cluster_nw_mtu}}}}'"
	echo $patch
	eval $patch
	
	#Wait MC and CO to rollout properly
	wait_mcp_co
}

pre_CNO_patch
post_CNO_patch
echo "Congratulations! MTU migration seems to be successful"
#Remove nmconnection files and yamls
rm -rf *.nmconnection
rm -rf *.yaml
