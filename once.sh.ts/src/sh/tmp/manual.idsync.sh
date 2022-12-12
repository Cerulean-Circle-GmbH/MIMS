ossh push.key dockerPI.root

cd ~/.ssh/ids
ossh pull.dir dockerPI.root .ssh/ids/once2023.githubCC 
#ossh pull.dir dockerPI.root .ssh/ids/githubCC.once2023
ossh pull.config dockerPI.root githubCC.once2023

ossh pull.id dockerPI.root



cd oosh
git config --global user.email "donges@dockerPi.root"
git config --global user.name "Marcel Donges"

git config pull.rebase false  


cd /home/shared/EAMD.ucp/Scenarios/localhost/EAM/1_infrastructure/Once.sh/sharedConfig/

cd 
cp -r config.initial/stateMachines/ config