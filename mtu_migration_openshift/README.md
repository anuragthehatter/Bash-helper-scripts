- Script take only one argument which is the desired cluster network MTU we want to migrate

  For example
  ```./mtu_migrate.sh 1600```
  
 - You env supppsed to have butane utlity installed which can be downloaded from https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane.
 
 - Migration takes approximately 20-30 minutes.
 
 - We copy the exisiting Network Manager Profiles from master and worker node which serves as the templates we use and we modify its connection.id, set autoconnect priority and remove uuid.
   
 - In .bu files we need to make sure path is different than what we get under original master/worker profiles and local should point to our local nmconnection templates.
