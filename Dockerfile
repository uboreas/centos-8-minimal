FROM centos:8
MAINTAINER alex4108@live.com
RUN dnf update -y
RUN dnf install -y yum-utils createrepo syslinux genisoimage isomd5sum bzip2 curl file git wget unzip
RUN curl -L -o /root/CentOS-8.1.1911-x86_64-boot.iso http://isoredirect.centos.org/centos/8/isos/x86_64/CentOS-8.1.1911-x86_64-boot.iso
RUN echo $(sha256sum /root/CentOS-8.1.1911-x86_64-boot.iso)
RUN curl -L -o /root/bootstrap.zip https://github.com/uboreas/centos-8-minimal/archive/ef31f862908af773c74c234353e6bbad48b1ef5e.zip
RUN unzip /root/bootstrap.zip -d /root/
RUN mv /root/centos-8-minimal-ef31f862908af773c74c234353e6bbad48b1ef5e/* /root/
COPY create_iso_in_container.sh /root/
RUN chmod +x create_iso_in_container.sh && /root/create_iso_in_conatainer.sh
CMD ["/bin/bash"]
