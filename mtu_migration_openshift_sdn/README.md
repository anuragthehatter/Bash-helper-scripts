- This for OpenShiftSDN

- Script take only two arguments which is the desired cluster network MTU and vpshere arguement is optional

  For example
  ```./mtu_migrate.sh 1600```
  
 - You env suppposed to have butane utlity installed which can be downloaded from https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane. Butane utility consumes butane configs and produce ignition configs. Its only available as last GA release. We can use last GA binary to test on current release
 
 - Migration takes approximately 20-30 minutes.
 
 - We copy the exisiting Network Manager Profile from master/worker node which serves as the template we use and we modify its connection.id, set autoconnect priority > 0 ,remove uuid and add mtu.
   
 - In .bu files we need to make sure path is different than what we get under original master/worker profiles and local should point to our local nmconnection template.
