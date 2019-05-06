#!/bin/bash

################################################################
# Script_Name : stackbuilder.sh
# Description : Build stack for application deployment.

# Compatibulity : ubuntu 18.04.1 and later
# Date : May 4th, 2019
# written by : Tadeo Gutierrez
# 
# Version : SB_VERSION export
# History : 0.3 - sourced by .bashrc

# 0.1 - Initial Script
# Disclaimer : Script provided AS IS. Use it at your own risk.
# Licence : MIT
##################################################################

export SB_VERSION="4.1.1"
validbash=0
os=${OSTYPE//[0-9.-]*/}
echo "Stackbuilder v $SB_VERSION $(date -r ~/stackbuilder.sh '+%m-%d-%Y %H:%M:%S')"
case "$os" in
  darwin)
    echo "I'm in a Mac"
    validbash=1
    ;;

  msys)
    echo "I'm in Windows using git bash"
    validbash=1
    ;;

  linux)
    echo "I'm in Linux"
     validbash=1
   ;;
  *)

  echo "Unknown Operating system $OSTYPE"
  exit 1
esac




function update-stackbuilder {
   
   git fetch --all
   git reset --hard origin/master
   git pull origin master
   if [ -f stackbuilder.sh ] && [ validbash=1 ]; then 
      echo "updating stackbuilder script for bash"
      cat ./stackbuilder.sh > ~/stackbuilder.sh
      #add source line if not in .bashrc
      grep -qxF 'source ~/stackbuilder.sh' ~/.bashrc || echo 'source ~/stackbuilder.sh' >> ~/.bashrc
      source ./stackbuilder.sh 
   else
    echo "You need to be inside a valid stackbuilder project and bash terminal"
   fi
   echo "Stack utilities updated to $SB_VERSION"
}

function stack-up {
  comment_acme_staging=" "
  comment_redirect="#"
  comment_acme="#"
  default_password="changeme"
  default_host="localhost"
   # Get script arguments for non-interactive mode
    while [ "$1" != "" ]; do
       case $1 in
           -m | --mysqlrootpwd )
               shift
               mysqlrootpwd="$1"
               ;;
           -a | --apidbpwd )
               shift
               apidbpwd="$1"
               ;;
           -d | --domain )
               shift
               $domain_name="$1"
               ;;

       esac
       shift
    done
  
    while true
    do
       read -s -p "Enter a MySQL ROOT Password: " mysqlrootpassword
       mysqlrootpassword="${mysqlrootpassword:-$default_password}"
       echo
       read -s -p "Confirm MySQL ROOT Password: " password2
       password2="${password2:-$default_password}"
       echo
       [ "$mysqlrootpassword" = "$password2" ] && break
       echo "Passwords don't match. Please try again."
       echo
    done
    echo
    while true
    do
       read -s -p "Enter a database user Password: " dbuserpassword
       dbuserpassword="${dbuserpassword:-$default_password}"
       echo
       read -s -p "Confirm database user Password: " password2
       password2="${password2:-$default_password}"
       echo
       [ "$dbuserpassword" = "$password2" ] && break
       echo "Passwords don't match. Please try again."
       echo
    done
    echo


    while true
    do
        read  -p "Enter DOMAIN (ENTER for $default_host): "  stackdomain  
        stackdomain="${stackdomain:-default_host}"
        echo
        [ -z "$stackdomain" ] && echo "Please provide a DOMAIN" || break
        echo
    done

    echo "STACK_MAIN_DOMAIN=$stackdomain" > ./.env

    while true
    do
        read  -p "Enter E-MAIL for certificates notifications (ENTER for admin@mail.com): "  
        certs_mail="${certs_mail:-admin@mail.com}"
        echo
        [ -z "$certs_mail" ] && echo "Please provide a valid mail for certs" || break
        echo
    done

    bash -c "cat > ./proxy/traefik.toml" <<-EOF
debug = false
logLevel = "ERROR"
defaultEntryPoints = ["https","http"]
[entryPoints]
  [entryPoints.http]
      address = ":80"
      $comment_redirect [entryPoints.http.redirect]
      $comment_redirect   entryPoint = "https"
  [entryPoints.https]
      address = ":443"
      [entryPoints.https.tls]
[retry]
[docker]
endpoint = "unix:///var/run/docker.sock"
domain = "$stackdomain"
watch = true
exposedByDefault = false
$comment_acme [acme]
$comment_acme  $comment_acme_staging caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
$comment_acme   email = "$certs_mail"
$comment_acme   storage = "acme/certs.json"
$comment_acme   entryPoint = "https"
$comment_acme   onHostRule = true
$comment_acme   [acme.httpChallenge]
$comment_acme      entryPoint = "http"
EOF

    addreplacevalue "ALLOWED_HOSTS = [" "ALLOWED_HOSTS = ['$stackdomain','127.0.0.1']" ./code/project/settings.py

    STACK_MAIN_DOMAIN=$stackdomain \
    MYSQL_ROOT_PASSWORD=$mysqlrootpassword \
    MYSQL_PASSWORD=$dbuserpassword \
    RDS_PASSWORD=$dbuserpassword \
    CURRENT_UID=$(id -u):$(id -g) \
    docker-compose up -d

}

function stack-build {
    docker-compose run app django-admin startproject project .
    docker-compose down --remove-orphans

}


function addreplacevalue {

   usesudo="$4"
   archivo="$3"
   nuevacad="$2"
   buscar="$1"
   temporal="$archivo.tmp.kalan"
   listalineas=""
   linefound=0       
   listalineas=$(cat $archivo)
   if [[ !  -z  $listalineas  ]];then
     #echo "buscando lineas existentes con:"
     #echo "$nuevacad"
     #$usesudo >$temporal
     while read -r linea; do
     if [[ $linea == *"$buscar"* ]];then
       #echo "... $linea ..."
       if [ ! "$nuevacad" == "_DELETE_" ];then
          ## just add new line if value is NOT _DELETE_
          echo $nuevacad >> $temporal
       fi
       linefound=1
     else
       echo $linea >> $temporal

     fi
     done <<< "$listalineas"

     cat $temporal > $archivo
     rm -rf $temporal
   fi
   if [ $linefound == 0 ];then
     echo "Adding new value to file: $nuevacad"
     echo $nuevacad>>$archivo
   fi
}