#!/bin/bash
### KVM Host provisioning script.
set -e
set -o nounset

### Removing alto-labs directory in case of unclean exit from the script.
rm -rf alto-labs

echo "Welcome to the Alto NUC provisioning script."
echo ""
## Get SiteID:
siteid="0"
until [ $siteid -ge 201 ] && [ $siteid -le 399 ]
do
  echo "Please provide SiteID: "
  read siteid
  if [ $siteid -lt 201 ] || [ $siteid -gt 399 ]
  then
    echo ""
    echo "SiteID $siteid outside of the allowed range (201-399)."
  fi
  echo ""
done

echo "Starting provisioning for site: $siteid"
echo ""

## Run GitHub OAuth script and clone the repository.
## Repeat the tasks until repository is cloned.

while ! python3 /opt/alto/bin/oauth.py; do
  echo "Generating new authorization token..."
  echo ""
  echo ""
done


### Change directory to alto-labs/ansible/ and setup pip environment.
### Note: we cannot use pipenv shell here.
cd alto-labs/ansible/stratus/
pipenv install
echo ""

## Ask for the password & decrypt site specific yaml.
## Repeat the tasks until password is correct.

export ANSIBLE_VAULT_IDENTITY_LIST=alto_nuc_$siteid@prompt

echo Starting ansible initial-provisioning playbook
while ! pipenv run ansible-playbook initial-provisioning.yml --extra-vars "target_hostname=alto-nuc-$siteid site_id=$siteid"; do
  echo "Retrying..."
done

### Run other tasks...
echo "Is it Gen11 node [Yes|No]:"
read gen11
if [ $gen11 == "Yes" ] 
then
  echo ""
  echo "Gen11 selected, need to upgrade kernel to fix network driver bug"
  ip route del default
  dhclient br0
  ip route add default via 192.168.1.1
  wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.15.47/amd64/linux-headers-5.15.47-051547-generic_5.15.47-051547.202206141802_amd64.deb
  wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.15.47/amd64/linux-headers-5.15.47-051547_5.15.47-051547.202206141802_all.deb
  wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.15.47/amd64/linux-image-unsigned-5.15.47-051547-generic_5.15.47-051547.202206141802_amd64.deb
  wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.15.47/amd64/linux-modules-5.15.47-051547-generic_5.15.47-051547.202206141802_amd64.deb

  sudo dpkg -i *.deb
  sudo apt -f install -y
  sudo apt --fix-broken install -y
  rm -rf linux-*
  echo "End of kernel patching for Gen11 - please reboot after initial provisioning is finished"
fi

echo ""
echo "End of initial provisioning"
sleep 5
### Remove alto-labs directory
rm -rf ~/alto-labs