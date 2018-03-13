FROM openjdk:8-jdk as build

RUN echo 'deb http://http.debian.net/debian jessie-backports main' >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends maven 

RUN curl -sSL https://github.com/confluentinc/common/archive/v3.3.1.tar.gz | tar -xz -f - \
    && (cd common-3.3.1; mvn install) \
    && curl -sSL https://github.com/confluentinc/rest-utils/archive/v3.3.1.tar.gz | tar -xz -f - \
    && (cd rest-utils-3.3.1; mvn install)

COPY . /schema-registry/
WORKDIR /schema-registry

RUN mvn package -Pstandalone

FROM openjdk:8

ENV DOCKERIZE_VERSION=v0.6.0
RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

ENV SCHEMA_REGISTRY_VERSION=3.3.1

COPY --from=build /schema-registry/package-schema-registry/target/kafka-schema-registry-package-${SCHEMA_REGISTRY_VERSION}-standalone.jar /usr/share/java/
ADD config/ /etc/schema-registry

ENV JMX_PORT=9999
ENV SCHEMA_REGISTRY_LOG4J_OPTS="-Dlog4j.configuration=file:/etc/schema-registry/log4j.properties -Dschema-registry.log.dir=/tmp" \
    SCHEMA_REGISTRY_HEAP_OPTS="-Xmx512M" \
    SCHEMA_REGISTRY_JVM_PERFORMANCE_OPTS="-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+DisableExplicitGC -Djava.awt.headless=true" \
    SCHEMA_REGISTRY_JMX_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.port=${JMX_PORT}"

EXPOSE 8081 ${JMX_PORT}

CMD dockerize -template /etc/schema-registry/schema-registry.properties.tmpl:/etc/schema-registry/schema-registry.properties \
    /usr/bin/java ${SCHEMA_REGISTRY_HEAP_OPTS} ${SCHEMA_REGISTRY_JVM_PERFORMANCE_OPTS} ${SCHEMA_REGISTRY_JMX_OPTS} ${SCHEMA_REGISTRY_LOG4J_OPTS} -jar /usr/share/java/kafka-schema-registry-package-${SCHEMA_REGISTRY_VERSION}-standalone.jar /etc/schema-registry/schema-registry.properties
