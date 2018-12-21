FROM ubuntu:18.04
LABEL Name=hadoop Version=0.0.1

USER root

#-------------------------------------------------------
#LINUX PACKAGES INSTALLATION
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

#-------------------------------------------------------
#CONFIGURING ENVIRONMENTAL VARIABLES
#-------------------------------------------------------

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/ \
    HADOOP_VERSION=2.9.2 \
    HIVE_HOME=/usr/local/hive \
    HADOOP_HOME=/usr/local/hadoop
ENV HADOOP_MAPRED_HOME=$HADOOP_HOME \
    HADOOP_COMMON_HOME=$HADOOP_HOME \
    HADOOP_HDFS_HOME=$HADOOP_HOME \
    HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native \
    HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native" \
    HADOOP_INSTALL=$HADOOP_HOME \
    HADOOP_CLASSPATH=$JAVA_HOME/lib/tools.jar \
    YARN_HOME=$HADOOP_HOME

#-------------------------------------------------------
#HADOOP INSTALLATION
#-------------------------------------------------------

# get hadoop project
RUN curl http://ftp.unicamp.br/pub/apache/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz --output hadoop.tar.gz
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
export HADOOP_HDFS_HOME=$HADOOP_HOME \
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native \
export HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native" \
export PATH=$PATH:$HADOOP_HOME/sbin \
export PATH=$PATH:$HADOOP_HOME/bin \
export HADOOP_INSTALL=$HADOOP_HOME \
export HADOOP_CLASSPATH=$JAVA_HOME/lib/tools.jar \
export YARN_HOME=$HADOOP_HOME \
export HIVE_HOME=/usr/local/hive \
export PATH=$PATH:$HIVE_HOME/bin' >> /root/.bashrc

ADD ./install/ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

ADD ./install/bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh && \
    chmod 700 /etc/bootstrap.sh

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
    $HADOOP_HOME/bin/hdfs dfs -mkdir /tmp && \
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/root && \
    $HADOOP_HOME/bin/hdfs dfs -put $HADOOP_HOME/etc/hadoop input && \
    $HADOOP_HOME/bin/hdfs dfs -chmod g+w /tmp && \
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