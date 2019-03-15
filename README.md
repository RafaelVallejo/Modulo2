# Proyecto Final Modulo 2

## Integrantes:
* Hernández González Ricardo Omar
* López Fernández Servando Miguel
* Vallejo Fernández Rafael Alejandro

### Detalles del script:

El script fue hecho en shell.
Cuenta con varias funciones, que nos ayudan a darle modularidad al código.

Lo primero que haremos será saber en qué sistema operativo nos encontramos, para eso tenemos una función para conocer esto:

```bash
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
```

Ahora dependiendo del sistema operativo, instalaremos las dependencias correspondientes para el servicio de drupal.

```bash
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
```

Tenemos otra función para checar si ya esta instalado git y compose. Para esto usamos el comando which que nos dará la ruta en donde esta instalado, en otro caso dará un error y entonces lo instalaremos.

```bash
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
```

Otra de las funciones es la creación del proyecto y las instalaciones de los módulos de drupal, para esto hacemos uso de compose.
Compose es una herramienta para la gestión de dependencias en PHP. Le permite declarar las bibliotecas de las que depende su proyecto y las administrará (instalará / actualizará) por usted. Drupal usa Composer para administrar las diversas bibliotecas de las que depende. Los módulos también pueden usar Composer para incluir bibliotecas de terceros. Las compilaciones de sitios de Drupal pueden usar Composer para administrar los diversos módulos que componen el sitio.

```bash
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
```

Para instalar los módulos

```bash
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
```

El sitio se actualiza con la siguiente función.

```bash
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
```

Donde primero se hace el respaldo del mismo, posteriormente se actualiza y se pregunta al usuario si el sitio es funcional, en caso de tener una respuesta negativa se hace la restauración del sitio anterior.


Para el caso de los entornos virtuales, se hicieron 2 funciones, la primera llamada virtual_host, la cual configura un virtual host para redireccionar a https, en caso de querer entrar al sitio por http.

```bash
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
```

También tenemos una función llamada vh, la cual si el so es centOS hace una configuración adicional en el servidor.

```bash
vh(){
  if [ $FLAG = 'C' ]
  then
     mkdir /etc/httpd/sites-available /etc/httpd/sites-enabled
     sh -c "echo 'IncludeOptional sites-enabled/*.conf' >> /etc/httpd/conf/httpd.conf"
  fi
}
```

Ya para invocar las funciones, se hace uso de optargs, la cual te ayuda a seleccionar una bandera al momento de ejecutar el script.

```bash
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
```

Cuenta con varias verificaciones, para que el script se deba ejecutar con sudo, para que los valores no esten vacios o para que las banderas sean correctas.
 

### Manual de Usuario

El script debe ejecutarse con permisos de superusuario.

1. Creación de proyecto (Drupal 7,59): 
```bash
sudo ./script.sh -i -p NOMBRE_PROY -d NOMBRE_DOM -s NOMBRE_SITIO -c
```

2. VirtualHost: 
```bash
sudo ./script.sh -p NOMBRE_PROY -d NOMBRE_DOM -s NOMBRE_SITIO -v -m
```

3. Para actualizar el sitio, que es la funcionalidad de este proyecto: 
```bash
sudo ./script.sh -p NOMBRE_PROY -d NOMBRE_DOM -s NOMBRE_SITIO -a
``` 
