FROM ubuntu:18.04
LABEL Name=hadoop Version=0.0.1

USER root

#-------------------------------------------------------
# HADOOP INSTALLER
#-------------------------------------------------------

RUN apt-get -y update && \
    apt-get clean && \
    apt-get autoremove && \
    apt-get -y install \
    autoconf \
    build-essential \
    ssh \
    rsync \
    net-tools \
    lsof \
    curl \
    openjdk-8-jdk

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/ \
    HADOOP_VERSION=2.9.2 \
    HIVE_HOME=/usr/local/hive \
    HADOOP_HOME=/usr/local/hadoop
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop \
    HADOOP_MAPRED_HOME=$HADOOP_HOME \
    HADOOP_COMMON_HOME=$HADOOP_HOME \
    HADOOP_PREFIX=$HADOOP_HOME \
    HADOOP_HDFS_HOME=$HADOOP_HOME \
    HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native \
    HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native" \
    HADOOP_INSTALL=$HADOOP_HOME \
    HADOOP_CLASSPATH=$JAVA_HOME/lib/tools.jar \
    YARN_HOME=$HADOOP_HOME

# get hadoop project
RUN wget -c --progress=bar:force:noscroll http://ftp.unicamp.br/pub/apache/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz -O hadoop.tar.gz
RUN tar -zxvf hadoop.tar.gz
RUN ln -s /hadoop-$HADOOP_VERSION ${HADOOP_HOME}
RUN ls -la ${HADOOP_HOME}
RUN chmod 777 -R ${HADOOP_HOME}/etc/hadoop


# ssh config
RUN yes y | ssh-keygen -q -P '' -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN yes y | ssh-keygen -q -P '' -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN yes y | ssh-keygen -q -P '' -t rsa -f /root/.ssh/id_rsa
RUN cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys

# ajustes
RUN mkdir -p $HADOOP_HOME/input
RUN cp $HADOOP_HOME/etc/hadoop/*.xml $HADOOP_HOME/input
ADD ./config $HADOOP_HOME/etc/hadoop
VOLUME /hadoop/data
RUN echo 'export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::") \
export HADOOP_HOME=/usr/local/hadoop \
export HADOOP_MAPRED_HOME=$HADOOP_HOME \
export HADOOP_COMMON_HOME=$HADOOP_HOME \
export HADOOP_PREFIX=$HADOOP_HOME \
export HADOOP_HDFS_HOME=$HADOOP_HOME \
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop \
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native \
export HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native" \
export HADOOP_INSTALL=$HADOOP_HOME \
export HADOOP_CLASSPATH=$JAVA_HOME/lib/tools.jar \
export YARN_HOME=$HADOOP_HOME' >> /root/.bashrc

ADD ./install/ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

ADD ./install/bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh && \
    chmod 777 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

SHELL [ "/bin/bash", "-c" ]

# workingaround docker.io build error
RUN ls -la $HADOOP_HOME/etc/hadoop/*-env.sh
RUN chmod +x $HADOOP_HOME/etc/hadoop/*-env.sh
RUN ls -la $HADOOP_HOME/etc/hadoop/*-env.sh

# fix the 254 error code
RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

RUN service ssh start && \
    $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    $HADOOP_HOME/bin/hdfs namenode -format && \
    $HADOOP_HOME/sbin/start-dfs.sh && \
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /tmp && \
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /tmp/spark-logs && \
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /data && \
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/root && \
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/hive/warehouse && \
    $HADOOP_HOME/bin/hdfs dfs -chmod g+w /tmp && \
    $HADOOP_HOME/bin/hdfs dfs -chmod g+w /user/hive/warehouse && \
    $HADOOP_HOME/bin/hdfs dfs -put $HADOOP_HOME/etc/hadoop input && \
    $HADOOP_HOME/bin/hdfs dfs -ls / && \
    $HADOOP_HOME/sbin/start-yarn.sh && \
    jps

CMD ["/etc/bootstrap.sh", "-d"]

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000 9870
# Mapred ports
EXPOSE 10020 19888
# Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
# Other ports
EXPOSE 49707 2122

# -------------------------------------------------------
# SPARK INSTALLER
# -------------------------------------------------------

RUN echo 'export SPARK_VERSION=2.4.0 \
export SPARK_HOME=/usr/local/spark' >> /root/.bashrc
ENV LD_LIBRARY_PATH=$HADOOP_HOME/lib/native \
    SPARK_VERSION=2.4.0 \
    SPARK_HOME=/usr/local/spark
RUN echo '\
    LD_LIBRARY_PATH=$HADOOP_HOME/lib/native' >> /root/.bashrc
RUN apt-get -y install \
    vim \
    python3 \
    python3-pip
RUN wget -c --progress=bar:force:noscroll http://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop2.7.tgz -O spark.tgz
RUN tar -zxvf spark.tgz
RUN ln -s /spark-${SPARK_VERSION}-bin-hadoop2.7 ${SPARK_HOME}
# RUN cp -f $SPARK_HOME/conf/spark-defaults.conf.template $SPARK_HOME/conf/spark-defaults.conf && \
#     echo "\
#     spark.master                        yarn \
#     spark.driver.memory                 1G \
#     spark.yarn.am.memory                1G \
#     spark.executor.memory               1G \
#     spark.eventLog.enabled              true \
#     spark.eventLog.dir                  hdfs://localhost:9000/tmp/spark-logs \
#     spark.history.fs.update.interval    10s \
#     spark.history.ui.port               18080" >> $SPARK_HOME/conf/spark-defaults.conf
# RUN $SPARK_HOME/sbin/start-history-server.sh

#-------------------------------------------------------
# HIVE INSTALLER
#-------------------------------------------------------

# ENV HIVE_VERSION=2.3.4 \
#     HIVE_HOME=/usr/local/hive
# RUN echo 'export HIVE_HOME=/usr/local/hive' >> /root/.bashrc
# RUN wget -c --progress=bar:force:noscroll http://mirror.nbtelecom.com.br/apache/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz -O apache-hive.tar.gz
# RUN tar -zxvf apache-hive.tar.gz
# RUN ln -s /apache-hive-${HIVE_VERSION}-bin ${HIVE_HOME}

#-------------------------------------------------------
# MONGODB INSTALLER
#-------------------------------------------------------

# RUN echo '\
#     MONGO_HADOOP_HOME=/usr/local/mongo-hadoop' >> /root/.bashrc
# ENV MONGO_HADOOP_HOME=/usr/local/mongo-hadoop \
#     MONGO_HADOOP_VERSION=2.0.2 \
#     MONGODB_DRIVER_VERSION=3.9.1
# RUN apt-get -y install mongodb
# RUN mkdir -p /data/db
# RUN wget -c --progress=bar:force:noscroll https://github.com/mongodb/mongo-hadoop/archive/r${MONGO_HADOOP_VERSION}.tar.gz -O mongo-hadoop.tar.gz
# RUN tar -zxvf mongo-hadoop.tar.gz
# RUN ln -s /mongo-hadoop-r${MONGO_HADOOP_VERSION} ${MONGO_HADOOP_HOME}
# RUN wget -c --progress=bar:force:noscroll https://oss.sonatype.org/content/repositories/releases/org/mongodb/mongodb-driver/${MONGODB_DRIVER_VERSION}/mongodb-driver-${MONGODB_DRIVER_VERSION}.jar -O $HADOOP_PREFIX/share/hadoop/common/mongodb-driver.jar
# RUN wget -c --progress=bar:force:noscroll http://repo1.maven.org/maven2/org/mongodb/mongo-hadoop/mongo-hadoop-spark/${MONGO_HADOOP_VERSION}/mongo-hadoop-spark-${MONGO_HADOOP_VERSION}.jar -O $HADOOP_PREFIX/share/hadoop/common/mongo-hadoop-spark.jar
# RUN wget -c --progress=bar:force:noscroll http://repo1.maven.org/maven2/org/mongodb/mongo-hadoop/mongo-hadoop-core/${MONGO_HADOOP_VERSION}/mongo-hadoop-core-${MONGO_HADOOP_VERSION}.jar -O $HADOOP_PREFIX/share/hadoop/common/mongo-hadoop-core.jar

# RUN cd $MONGO_HADOOP_HOME/spark/src/main/python; \
#     python3 setup.py install; \
#     pip3 install pymongo

#RUN $MONGO_HADOOP_HOME/gradlew jar 
#RUN mongod --config /etc/mongodb.conf
#RUN mongoimport database.csv --type csv --headerline --db data_test