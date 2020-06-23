FROM debian:stretch

RUN apt-get update && apt-get install -y \
    bash-completion \
    gcc \
    dnsutils \
    libc-dev \
    make \
    python-dev \
    python \
    python3 \
    python-pip \
    python3-pip \
    curl \
    vim \
    ssh \
    unzip \
    git \
    sudo \
    jq  \
    wget \
    openjdk-8-jdk 


ENV TF_11_VER="0.11.11"
ENV TF_12_VER="0.12.18"
ENV DEPLOY_DIR="/deployment"

# Install terraform 11
RUN curl -O https://releases.hashicorp.com/terraform/${TF_11_VER}/terraform_${TF_11_VER}_linux_amd64.zip \
 && unzip terraform_${TF_11_VER}_linux_amd64.zip -d /bin \
 && mv /bin/terraform /usr/local/bin/tf_11 \
 && rm terraform_${TF_11_VER}_linux_amd64.zip

# Install terraform 12
RUN curl -O https://releases.hashicorp.com/terraform/${TF_12_VER}/terraform_${TF_12_VER}_linux_amd64.zip \
 && unzip terraform_${TF_12_VER}_linux_amd64.zip -d /bin \
 && mv /bin/terraform /usr/local/bin/tf_12 \
 && rm terraform_${TF_12_VER}_linux_amd64.zip

# Add non-root user
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN userdel $(cat /etc/passwd | grep ${USER_ID} | cut -f1 -d:) -f 2> /dev/null || true \
 && groupdel $(cat /etc/group | grep ${GROUP_ID} | cut -f1 -d:) -f 2> /dev/null || true \
 && groupadd -r -g ${GROUP_ID} deployer \
 && useradd --no-log-init -s /bin/bash -u ${USER_ID} -d /home/deployer -g deployer deployer \
 && mkdir -p /home/deployer/.ssh \
 && chown -R deployer:deployer /home/deployer \
 && echo 'deployer ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Install helm from USER deployer
ENV HELM_VERSION v2.13.1
ENV HELM_DIFF_VERSION 3.0.0-rc.7
ENV HELM_FILENAME helm-${HELM_VERSION}-linux-amd64.tar.gz
ENV HELM_URL https://storage.googleapis.com/kubernetes-helm/${HELM_FILENAME}

RUN echo $HELM_URL

USER deployer

RUN curl -o /tmp/$HELM_FILENAME ${HELM_URL}  \
 && tar -zxvf /tmp/${HELM_FILENAME} -C /tmp \
 && sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm \
 && rm -rf /tmp/linux-amd64
RUN helm init --client-only \
 && helm plugin install https://github.com/databus23/helm-diff --version ${HELM_DIFF_VERSION}

USER root

# Install kubectl
ENV KUBECTL_VERSION=v1.11.5

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
 && chmod +x ./kubectl \
 && mv ./kubectl /usr/local/bin/kubectl


# Install kops
ENV KOPS_VERSION=1.13.0

RUN curl -Lo kops https://github.com/kubernetes/kops/releases/download/${KOPS_VERSION}/kops-linux-amd64 \
 && chmod +x ./kops \
 && mv ./kops /usr/local/bin/

# Install aws-iam-authenticator
RUN curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/aws-iam-authenticator \
 && chmod +x ./aws-iam-authenticator \
 && mv ./aws-iam-authenticator /usr/bin/aws-iam-authenticator

# Install pip requirements
# COPY requirements.txt /requirements.txt
# RUN pip3 install --no-cache-dir -r /requirements.txt
RUN pip3 install --no-cache-dir fire==0.2.1 \
 j2cli==0.3.10 \
 boto3==1.9.231 \
 kubernetes==10.0.1 \
 awscli==1.16.283 \
 jmespath==0.9.5 \
 PyYAML==5.3 \
 PyGithub==1.51 \
 pyhcl==0.4.4

############### Allure
ENV ALLURE_VERSION=2.8.0
RUN curl -O  https://repo.maven.apache.org/maven2/io/qameta/allure/allure-commandline/${ALLURE_VERSION}/allure-commandline-2.8.0.zip \
 && unzip allure-*.zip -d /opt \
 && rm allure*.zip 

########## gradle 
ENV GRADLE_VERSION=5.4.1
RUN wget  https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
 && unzip gradle*.zip -d /opt \
 && rm gradle*.zip 

########## Maven 
ENV MAVEN_VERSION=3.6.1
RUN wget  http://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
 &&   tar xzf apache-maven-*-bin.tar.gz -C /opt/ \
 && rm apache-maven-*.tar.gz \
 && ln -s /opt/apache-maven-*/bin/mvn /usr/local/bin/mvn \
 && ln -s /opt/apache-maven-*/bin/mvnDebug /usr/local/bin/mvnDebug


ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$PATH:/opt/allure-${ALLURE_VERSION}/bin
ENV GRADLE_HOME=/opt/gradle-${GRADLE_VERSION}


# Set up helpers
COPY helper-scripts/* /usr/local/bin/
COPY .bashrc /home/deployer/.bashrc
COPY .bash_aliases /home/deployer/.bash_aliases

RUN chown -R deployer:deployer /usr/local/bin && \
    chown -R deployer:deployer /home/deployer/.bash_*


RUN chmod -R 777 /usr/local/bin

WORKDIR /deployment

USER deployer

RUN bash -c "source /home/deployer/.bashrc && set_tf_12"
