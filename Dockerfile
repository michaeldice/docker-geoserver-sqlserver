# references
# https://github.com/eliotjordan/docker-geoserver
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
# https://docs.geoserver.org/stable/en/user/installation/linux.html
# http://docs.geonode.org/en/master/tutorials/advanced/geonode_production/adv_gsconfig/gsproduction.html

FROM openjdk:8-jre-alpine

ARG GS_VERSION=2.16.2
ARG GS_ARCHIVE_FILENAME=geoserver-${GS_VERSION}-bin.zip
ARG GS_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/${GS_ARCHIVE_FILENAME}
ARG GS_SQLSERVER_FILENAME=geoserver-${GS_VERSION}-sqlserver-plugin.zip
ARG GS_SQLSERVER_URL=http://sourceforge.net/projects/geoserver/files/GeoServer/${GS_VERSION}/extensions/${GS_SQLSERVER_FILENAME}
ARG GS_VECTORTILES_FILENAME=geoserver-${GS_VERSION}-vectortiles-plugin.zip
ARG GS_VECTORTILES_URL=http://sourceforge.net/projects/geoserver/files/GeoServer/${GS_VERSION}/extensions/${GS_VECTORTILES_FILENAME}
ARG MS_JDBC_FILENAME=sqljdbc_6.0.8112.200_enu.tar.gz
ARG MS_JDBC_URL=https://download.microsoft.com/download/0/2/A/02AAE597-3865-456C-AE7F-613F99F850A8/${MS_JDBC_FILENAME}

WORKDIR /tmp

# for correct cpu/memory detection inside a container
ENV JAVA_OPTS -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap
ENV GEOSERVER_HOME /opt/geoserver
ENV DISABLE_GEOSERVER_CONSOLE false
ENV GEOSERVER_DATA_DIR /home/geoserver-data
ENV GEOWEBCACHE_CACHE_DIR /home/geoserver-gwc

# need these just during build
RUN apk add --no-cache wget unzip

RUN set -ex && \
    # download and extract geoserver archive
    wget "$GS_URL" && \
    unzip "$GS_ARCHIVE_FILENAME" && \
    mkdir -p "/opt" && \
    mv "geoserver-$GS_VERSION" "$GEOSERVER_HOME" && \
    chmod +x "${GEOSERVER_HOME}/bin/startup.sh" && \
    # clean up
    rm "$GS_ARCHIVE_FILENAME"

RUN set -ex && \
    # download and extract geoserver MSSQL plugin
    wget "$GS_SQLSERVER_URL" && \
    unzip "$GS_SQLSERVER_FILENAME" && \
    mv gt-jdbc-sqlserver-22.2.jar /opt/geoserver/webapps/geoserver/WEB-INF/lib/gt-jdbc-sqlserver-22.2.jar && \
    # clean up
    rm "$GS_SQLSERVER_FILENAME"

RUN set -ex && \
    # download and extract geoserver Vector Tiles plugin
    wget -O "$GS_VECTORTILES_FILENAME" "$GS_VECTORTILES_URL" &&\
    unzip "$GS_VECTORTILES_FILENAME" -d /opt/geoserver/webapps/geoserver/WEB-INF/lib &&\
    rm "$GS_VECTORTILES_FILENAME"

RUN set -ex && \
    # download and extract Microsoft JDBC driver
    wget "$MS_JDBC_URL" && \
    tar -xvzf  "$MS_JDBC_FILENAME" && \
    mv ./sqljdbc_6.0/enu/jre8/sqljdbc42.jar /opt/geoserver/webapps/geoserver/WEB-INF/lib/sqljdbc42.jar && \
    # clean up
    rm "$MS_JDBC_FILENAME"

# enable CORS 
RUN wget -q https://repo.maven.apache.org/maven2/org/eclipse/jetty/jetty-servlets/9.4.12.v20180830/jetty-servlets-9.4.12.v20180830.jar -P /opt/geoserver/webapps/geoserver/WEB-INF/lib \
    && sed -i 's_<!-- <filter>_<filter>_' /opt/geoserver/webapps/geoserver/WEB-INF/web.xml \
    && sed -i 's_</filter> -->_</filter>_' /opt/geoserver/webapps/geoserver/WEB-INF/web.xml \
    && sed -i 's_<!-- <filter-mapping>_<filter-mapping>_' /opt/geoserver/webapps/geoserver/WEB-INF/web.xml \
    && sed -i 's_</filter-mapping> -->_</filter-mapping>_' /opt/geoserver/webapps/geoserver/WEB-INF/web.xml

RUN apk del --no-cache wget unzip

COPY startup-geoserver-base.sh /startup-geoserver-base.sh
COPY startup-geoserver-azure-web-app.sh /startup-geoserver-azure-web-app.sh
# sshd_config from https://raw.githubusercontent.com/Azure-App-Service/node/master/8.2.1/sshd_config
COPY sshd_config /etc/ssh/sshd_config

RUN set -ex && \
    # need this for ssh access to the running container
    apk add --no-cache openssh openrc && \
    # configure ssh access (don't worry it's via the Azure App Service platform, there's no external access)
    echo "root:Docker!" | chpasswd && \
    chmod 0555 /startup-geoserver-azure-web-app.sh && \
    chmod 0555 /startup-geoserver-base.sh

EXPOSE 2222 8080
ENTRYPOINT ["/startup-geoserver-azure-web-app.sh"]

#EXPOSE 8080
#ENTRYPOINT ["/startup-geoserver-base.sh"]
#RUN chmod +x /opt/geoserver/bin/startup.sh
#ENTRYPOINT ["/opt/geoserver/bin/startup.sh"]
