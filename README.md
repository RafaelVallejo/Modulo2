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
}
```

Ahora dependiendo del sistema operativo, instalaremos las dependencias correspondientes para el servicio de drupal.

```bash
install_dep(){
  if [ $FLAG = 'D9' ]
    then
      apt install ca-certificates apt-transport-https -y
      wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add -
      echo "deb https://packages.sury.org/php/ stretch main" | tee /etc/apt/sources.list.d/php.list
      apt update
      apt install postgresql php7.1 php7.1-common php7.1-curl php7.1-gd php7.1-json php7.1-mbstring php7.1-pgsql php7.1-xml unzip -y
  elif [ $FLAG = 'D8' ]
    then
      apt install ca-certificates apt-transport-https -y
      wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add -
      echo "deb https://packages.sury.org/php/ jessie main" | tee /etc/apt/sources.list.d/php.list
      apt update
      apt install postgresql php7.1 php7.1-common php7.1-curl php7.1-gd php7.1-json php7.1-mbstring php7.1-pgsql php7.1-xml unzip -y
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
      if [ $FLAG = 'C' ]
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

  if [ $(which drush) ]
    then
        echo $(drush version)
    else
        # Instalación de drush
        composer global require consolidation/cgr
       # PATH="$(composer config -g home)/vendor/bin:$PATH"
       PATH="/$PROYECTO/vendor/bin:$PATH"
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
  #PATH="$(composer config -g home)/vendor/bin:$PATH"
  PATH="/$PROYECTO/vendor/bin:$PATH"
  drush archive-dump --root=$SITIO --destination=$SITIO.tar.gz -v --overwrite
  cd /$PROYECTO
  drush vset --exact maintenance_mode 1
  drush cache-clear all
  drush pm-update drupal --pm-force
  drush vset --exact maintenance_mode 0
  read -p "¿El sitio es funcional? [Y/N]: " resp
  case $resp in
    y|Y)drush cache-clear all
        echo "Se actualizó el sitio y la versión de Drupal a 7.64";;
    n|N|*)restaura
          echo "Se restauro el sitio con Drupal 7.59";;
  esac
  chmod 444 /$PROYECTO/web/sites/default/settings.php
  cd -
}
```

Donde primero se hace el respaldo del mismo, posteriormente se actualiza y se pregunta al usuario si el sitio es funcional, en caso de tener una respuesta negativa se hace la restauración del sitio anterior.


Para el caso de los entornos virtuales, se hicieron 2 funciones, la primera llamada virtual_host, la cual configura un virtual host para redireccionar a https, en caso de querer entrar al sitio por http.

```bash
virtual_hovirtual_host(){
  if [ $FLAG = 'C' ]
    then
      yum install mod_ssl openssl
      SISTEMA=/etc/httpd/sites-available/$DOMAIN.conf
  else
      SISTEMA=/etc/apache2/sites-available/$DOMAIN.conf
  fi

  openssl genrsa -out ca.key 2048
  openssl req -new -key ca.key -out ca.csr
  openssl x509 -req -days 365 -in ca.csr -signkey ca.key -out ca.crt

  mv ca.crt /root/
  mv ca.key /root/
  mv ca.csr /root/

  echo "
  <VirtualHost *:80>
    ServerName www.$DOMAIN
    Redirect / https://www.$DOMAIN
    ServerAlias $DOMAIN
  </VirtualHost>

  <VirtualHost _default_:443>
    ServerName www.$DOMAIN
    ServerAlias $DOMAIN
    DocumentRoot /var/www/$DOMAIN
    #ErrorLog /var/www/$DOMAIN/error.log
    #CustomLog /var/www/$DOMAIN/requests.log combined
    SSLEngine On
    SSLCertificateFile /root/ca.crt
    SSLCertificateKeyFile /root/ca.key
  </VirtualHost>" |  tee $SISTEMA
    ln -s /$PROYECTO/web /var/www/$DOMAIN

    if [ $FLAG = 'D9' ] || [ $FLAG = 'D8' ]
    then
      sed -i 's#/var/www/html#/var/www#' /etc/apache2/apache2.conf
      cd /etc/apache2/sites-available/
      a2ensite $DOMAIN.conf
      a2enmod rewrite
      a2enmod ssl
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

Cuando se actualiza el sitio se pregunta si es funcional, en caso de dar una respuesta positiva y luego querer restaurar el sitio, existe una función para eso.

```bash
restaura(){
  #PATH="$(composer config -g home)/vendor/bin:$PATH"
  PATH="/$PROYECTO/vendor/bin:$PATH"
  unlink /var/www/$RESPALDO
  rm -Rf /$PROYECTO/web
  drush archive-restore $SITIO.tar.gz $RESPALDO --destination=/$PROYECTO/web
  ln -s /$PROYECTO/web /var/www/$DOMAIN
  chmod 444 /$PROYECTO/web/sites/default/settings.php

}
```

Primero se verifica que el script haya sido ejecutado como root, ya que necesitamos permisos para instalar las dependencias.
```bash
if [ $(id -u) -ne 0 ]
  then
    echo "Ejecuta as root"
    exit
fi
cd /
so
```

Ya para invocar las funciones, se hace uso de optargs, la cual te ayuda a seleccionar una bandera al momento de ejecutar el script.

```bash
while getopts p:d:s:aicvmr opcion
  do
    case "${opcion}" in
      p) PROYECTO=${OPTARG};;
      d) DOMAIN=${OPTARG}; DIR=`echo $DOMAIN | cut -d. -f1`;;
      s) SITIO=${OPTARG}; RESPALDO=`echo $SITIO | rev | cut -d/ -f1 | rev`;;
      a) OPCION='A';;
      i) OPCION='I';;
      c) OPCION='C';;
      v) OPCION='V';;
      m) OPCION='M';;
      r) OPCION='R';;
    esac
done
```

Se verifica que los argumentos no se encuentren vacios.
```bash
if [ -z "$PROYECTO" ] && [ -z "$DOMAIN" ] && [ -z "$SITIO" ] && [ $OPCION != 'I' ]
	then
		echo "Faltan argumentos!"
		exit

fi
```

Y por último se hacen las validaciones y aplicaciones de funciones de acuerdo a las banderas que fueron ingresadas, como la a para actualizar, la r para restaurar, la m para crear virtual host y la c para crear el sitio.


### Manual de Usuario

El script debe ejecutarse con permisos de superusuario.

1. Instalación de dependencias:
```bash
sudo ./script.sh -i
```

2. Creación de proyecto e instalación de módulos(Drupal 7,59): 
```bash
sudo ./script.sh -s /var/www/NOMBRE_SITIO -d NOMBRE_DOMINIO -p NOMBRE_PROYECTO -c
```

3. Creación de un VirtualHost con redireccion a https: 
```bash
sudo ./script.sh -s /var/www/NOMBRE_SITIO -d NOMBRE_DOMINIO -p NOMBRE_PROYECTO -m
```

4. Para actualizar el sitio, que es la funcionalidad de este proyecto: 
```bash
sudo ./script.sh -s /var/www/NOMBRE_SITIO -d NOMBRE_DOMINIO -p NOMBRE_PROYECTO -a
``` 

5. En caso de querer restaurar el sitio:
```bash
sudo ./script.sh -s /var/www/NOMBRE_SITIO -d NOMBRE_DOMINIO -p NOMBRE_PROYECTO -r
```

#### Referencias:
* https://www.drupal.org/docs/develop/using-composer/using-composer-to-install-drupal-and-manage-dependencies
* https://www.drupal.org/docs/develop/using-composer
* https://www.tecmint.com/redirect-http-to-https-on-apache/
* https://www.tecmint.com/apache-security-tips/
* https://www.guru99.com/postgresql-create-database.html
* https://geekflare.com/http-header-implementation/
* https://geekflare.com/apache-web-server-hardening-security/
* https://www.linux-party.com/4-apache/9201-como-configurar-https-en-apache-web-server-con-centos
* https://github.com/consolidation/cgr#installation-and-usage