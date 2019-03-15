# Ejecución:
# 1) Creación de proyecto (Drupal 7,59): sudo ./script.sh -i -p NOMBRE_PROY -d NOMBRE_DOM -s NOMBRE_SITIO -c
# 2) VirtualHost en centOS y Debian (falta probar Debian 9): sudo ./script.sh -p NOMBRE_PROY -d NOMBRE_DOM -s NOMBRE_SITIO -v -m
#   2.1) Si se quieren agregar más VirtualHost, quitar la opción -v
## Meter en i) [linea 188] la función: modulos  para que los instale pero tarda más, eso al final
# Para lo que pide en el proyecto realmente, es la función actualiza (tenemos que checar lo de respaldos de los sitios y que reciba la ruta completa o nombre):
# Se ejecutaría así: sudo ./script.sh -p NOMBRE_PROY -d NOMBRE_DOM -s NOMBRE_SITIO -a
### Falta también configurar en el entorno lo de https, secure headers y htaccess


#Requisitos
install_dep(){
  if [ $FLAG = 'D9' ]
    then
      apt install ca-certificates apt-transport-https -y
      wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add -
      echo "deb https://packages.sury.org/php/ jessie main" | tee /etc/apt/sources.list.d/php.list
      apt update
      apt install postgresql php7.2 php7.2-common php7.2-curl php7.2-gd php7.2-json php7.2-mbstring php7.2-pgsql php7.2-xml unzip -y
  elif [ $FLAG = 'D8' ]
    then
      apt install ca-certificates apt-transport-https -y
      wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add -
      echo "deb https://packages.sury.org/php/ jessie main" | tee /etc/apt/sources.list.d/php.list
      apt update
      apt install postgresql php7.2 php7.2-common php7.2-curl php7.2-gd php7.2-json php7.2-mbstring php7.2-pgsql php7.2-xml unzip -y
  else
    yum install wget httpd postgresql postgresql-server php php-curl php-gd php-pdo.x86_64 php-pgsql.x86_64 php-xml php-mbstring.x86_64 unzip -y
  fi
}

# Verifica existencia de git, composer
existencia(){
  if [ $(which git) ]
  then
      echo $(git version)
  else
      if [ $FLAG = 'C']
      then
        yum install git -y
      else
        apt install git -y
      fi
  fi

  if [ $(which composer) ]
    then
        echo $(composer --version)
    else
        # Instalación de composer
         wget https://getcomposer.org/installer
         mv installer composer-setup.php
         php composer-setup.php
         rm composer-setup.php
         mv composer.phar /usr/bin/composer
  fi

}

# Se crea proyecto con Drupal 7.59
creacion_proyecto(){
  cd /
   composer create-project drupal-composer/drupal-project:7.x-dev --no-dev $PROYECTO --no-interaction --ignore-platform-reqs --no-install

  # Se cambia versión core de Drupal por 7.59

  sed -i 's/ext-pdo_mysql/ext-pdo_pgsql/' $PROYECTO/composer.json
  sed -i 's#"drupal/drupal":.*".*"#"drupal/drupal": "7.59"#' $PROYECTO/composer.json
  sed -i 's#"drupal/core":.*"#"drupal/core": "*"#' $PROYECTO/composer.json
  cd $PROYECTO
  composer install
  cd ..
  composer global require drush/drush
}

# Se configura y hablita VirtualHost  args: web.prueba web
virtual_host(){
  if [ $FLAG = 'C' ]
    then
      SISTEMA=/etc/httpd/sites-available/$DOMAIN.conf
  else
      SISTEMA=/etc/apache2/sites-available/$DOMAIN.conf
  fi

  echo "
    <VirtualHost *:80>
      ServerName www.$DOMAIN
  #      Redirect / https://www.web.prueba
  #    </VirtualHost>

  #    <VirtualHost _default_:443>
  #      ServerName www.web.prueba
      ServerAlias $DOMAIN
      DocumentRoot /var/www/$DOMAIN
      ErrorLog /var/www/$DOMAIN/error.log
      CustomLog /var/www/$DOMAIN/requests.log combined
  #      SSLEngine On
    </VirtualHost>" |  tee $SISTEMA
     ln -s /$PROYECTO/web /var/www/$DOMAIN

    if [ $FLAG = 'D9' ] || [ $FLAG = 'D8' ]
    then
      sed -i 's#/var/www/html#/var/www#' /etc/apache2/apache2.conf
      cd /etc/apache2/sites-available/
      a2ensite $DOMAIN.conf
      cd -
      service apache2 restart
    else
      ln -s /etc/httpd/sites-available/$DOMAIN.conf  /etc/httpd/sites-enabled/$DOMAIN.conf
      setenforce 0
      service httpd restart
    fi

}

# Módulos
modulos(){
  cd $PROYECTO
   composer require drupal/ctools
   composer require drupal/event_log
   composer require drupal/google_analytics
   composer require drupal/workflow
   composer require drupal/ckeditor
   composer require drupal/jquery_update
   composer require drupal/panopoly_i18n
   composer require drupal/features_translations
   composer require drupal/site_map
   composer require drupal/token
   composer require drupal/panels_mini_ipe
   composer require drupal/panels
   composer require drupal/rules
   composer require drupal/captcha
   composer require drupal/views
   composer require drupal/business_responsive_theme
}

# Configura entorno VH
vh(){
  if [ $FLAG = 'C' ]
  then
     mkdir /etc/httpd/sites-available /etc/httpd/sites-enabled
     sh -c "echo 'IncludeOptional sites-enabled/*.conf' >> /etc/httpd/conf/httpd.conf"
  fi
}

actualiza(){
  drush archive-dump --root=$SITIO --destination=$SITIO.tar.gz -v --overwrite
  drush vset --exact maintenance_mode 1
  drush cache-clear all
  drush pm-update drupal --pm-force
  read -p "¿El sitio es funcional? [Y/N]: " resp
  case $resp in
    y|Y)drush vset --exact maintenance_mode 0
        drush cache-clear all;;
    n|N|*)unlink /var/www/$RESPALDO
          drush archive-restore $SITIO.tar.gz $RESPALDO --destination=/$PROYECTO/web
          ln -s /$PROYECTO/web /var/www/$DOMAIN;;
  esac
}
so(){
  FLAG=0
  if [ `cat /etc/issue | grep -E 'Debian.*9'| wc -l` = '1' ]
    then
      FLAG='D9'
  elif [ `cat /etc/issue | grep -E 'Debian.*8'| wc -l` = '1' ]
      then
        FLAG='D8'
  else
    FLAG='C'
  fi
  echo $FLAG
}


if [ $(id -u) -ne 0 ]
  then
    echo "Ejecuta as root"
    exit
fi
cd /
so

OPCION='X'

while getopts p:d:s:aicvm opcion
  do
    case "${opcion}" in
      p) PROYECTO=${OPTARG};;
      d) DOMAIN=${OPTARG}; DIR=`echo $DOMAIN | cut -d. -f1`;;
      s) SITIO=${OPTARG}; $RESPALDO=`echo $SITE | rev | cut -d/ -f1 | rev`;;
      a) OPCION='A';;
      i) OPCION='I';;
      c) OPCION='C';;
      v) OPCION='V';;
      m) OPCION='M';;
    esac
done


if [ -z "$PROYECTO" ] && [ -z "$DOMAIN" ] && [ -z "$SITIO" ]
	then
		echo "Faltan argumentos!"
		exit

fi

if [ $OPCION = 'A' ]
	then
    if [ ! -e "$SITIO" ]
    	then
    		echo "El directorio no existe"
    		exit
    fi
	actualiza
elif [ $OPCION = 'I' ]
	then
		install_dep;existencia
elif [ $OPCION = 'C' ]
	then
		creacion_proyecto
elif [ $OPCION = 'V' ]
	then
		vh
elif [ $OPCION = 'M' ]
	then
		virtual_host
fi
