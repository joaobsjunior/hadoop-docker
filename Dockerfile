FROM ubuntu:18.04
LABEL Name=hadoop Version=0.0.1

USER root

#-------------------------------------------------------
#LINUX PACKAGES INSTALLATION
#-------------------------------------------------------

RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get clean && \
    apt-get autoremove && \
    apt-get -y install \
    ssh \
    rsync \
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

#get hadoop project
RUN curl http://ftp.unicamp.br/pub/apache/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz --output hadoop.tar.gz
RUN tar -zxvf hadoop.tar.gz && mv ./hadoop-$HADOOP_VERSION /usr/local/hadoop
ADD ./config $HADOOP_HOME/etc/hadoop
RUN chmod 777 -R $HADOOP_HOME/etc/hadoop

#ssh config
RUN yes y | ssh-keygen -t rsa -N '' -P '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
ADD ./install/ssh_config ~/.ssh/config
RUN service ssh start && service ssh restart && service ssh force-reload

#create hdfs
RUN $HADOOP_HOME/bin/hdfs namenode -format

RUN $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    $HADOOP_HOME/sbin/start-dfs.sh && \
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/root

ADD ./install/bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh && \
    chmod 700 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

CMD ["/etc/bootstrap.sh", "-d"]

# # Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# # Mapred ports
EXPOSE 10020 19888
# #Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
# #Other ports
EXPOSE 49707 2122

ENTRYPOINT /bin/bash