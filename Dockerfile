# Build JRE, which needs to be separated to a more proper base image
FROM openjdk:8-jdk-slim@sha256:e54d401f6bdd8a00b2d8837038b0a63da2cf527ce52849e351af435d2f650dae

ARG KAFKA_MONITOR_VERSION
ARG KAFKA_MONITOR_SHA256

ENV KAFKA_MONITOR_REPO=https://github.com/linkedin/kafka-monitor \
    KAFKA_MONITOR_VERSION=2.0.1 \
    KAFKA_MONITOR_SHA256=144777b7b6a2844acb7baf31aaf3aec0ce6c2e4ded91e3ad552c0f3032d60c9a
 
RUN set -ex; \
  export DEBIAN_FRONTEND=noninteractive; \
  runDeps=''; \
  buildDeps='curl ca-certificates unzip'; \
  apt-get update && apt-get install -y $runDeps $buildDeps --no-install-recommends; \
  \
  \
  echo "===> Installing Gradle"           && \
  cd /opt; \
  GRADLE_VERSION=4.10.2 PATH=$PATH:$(pwd)/gradle-$GRADLE_VERSION/bin; \
  curl -SL -o gradle-$GRADLE_VERSION-bin.zip https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip; \
  echo "b49c6da1b2cb67a0caf6c7480630b51c70a11ca2016ff2f555eaeda863143a29  gradle-$GRADLE_VERSION-bin.zip" | sha256sum -c -; \
  unzip gradle-$GRADLE_VERSION-bin.zip; \
  rm gradle-$GRADLE_VERSION-bin.zip; \
  gradle -v; \
  \
  \
  echo "===> Building Kafka-Monitor $KAFKA_MONITOR_VERSION"           && \
  mkdir -p /opt/kafka-monitor; \
  curl -SL -o monitor.tar.gz -SLs "$KAFKA_MONITOR_REPO/archive/$KAFKA_MONITOR_VERSION.tar.gz"; \
  echo "$KAFKA_MONITOR_SHA256  monitor.tar.gz" | sha256sum -c; \
  tar -xzf monitor.tar.gz --strip-components=1 -C /opt/kafka-monitor; \
  rm monitor.tar.gz; \
  \
  \
  cd /opt/kafka-monitor; \
  rm gradlew; \
  gradle --no-daemon jar; \
  \
  sed -i 's/localhost:2181/zookeeper:2181/' config/kafka-monitor.properties; \
  sed -i 's/localhost:9092/bootstrap:9092/' config/kafka-monitor.properties; \
  \
  cat config/kafka-monitor.properties; \
  cat config/log4j.properties; \
  \
  rm -rf /opt/gradle* /root/.gradle; \
  \
  apt-get purge -y --auto-remove $buildDeps nodejs; \
  rm -rf /var/lib/apt/lists/*; \
  rm -rf /var/log/dpkg.log /var/log/alternatives.log /var/log/apt

# 2nd stage
FROM openjdk:8-jre-slim@sha256:c2b5a617ddf1706cdc4b99f541ce84c27c98d101ebfe3c0490e6e57fa3ed5743

RUN mkdir -p /opt/kafka-monitor

COPY --from=0 /opt/kafka-monitor/bin /opt/kafka-monitor/bin
COPY --from=0 /opt/kafka-monitor/build /opt/kafka-monitor/build
COPY --from=0 /opt/kafka-monitor/webapp /opt/kafka-monitor/webapp
COPY --from=0 /opt/kafka-monitor/config /opt/kafka-monitor/config
COPY --from=0 /opt/kafka-monitor/docker/kafka-monitor-docker-entry.sh /opt/kafka-monitor/kafka-monitor-docker-entry.sh
  

WORKDIR /opt/kafka-monitor

ENTRYPOINT ["./bin/kafka-monitor-start.sh"]
CMD ["/opt/kafka-monitor/config/kafka-monitor.properties"]