- This for OVNKubernetes

- Script take only 3 arguments which is the desired cluster network MTU, and vpshere and ipsec are optional

  For example
  ```./mtu_migrate.sh 1600```
  
  if ipsec is needed as 3rd arguement, it needs to go with 2nd rguement which is cloud platforms like azure, aws, vsphere etc 
  
 - Your env suppposed to have butane utlity installed which can be downloaded from https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane. Butane utility consumes butane configs and produce ignition configs. Its only available as last GA release. We can use last GA binary to test on current release. ```mv``` it under /usr/bin and chmod 777.
 
 - Migration takes approximately 20-30 minutes.
 
 - We copy the exisiting Network Manager Profile from master/worker node which serves as the template we use and we modify its connection.id, set autoconnect priority < 100 and remove uuid.
   
 - In .bu files we need to make sure path is different than what we get under original master/worker profile and local should point to our local nmconnection template.
