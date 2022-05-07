FROM quay.io/centos/centos:stream8

ENV TERM xterm-256color
ENV USERHOME=/root
USER 0
WORKDIR $USERHOME

COPY iso-input/isolinux.cfg \
     # Downloaded xmls for repo 
     #iso-input/repo \
     config /root/

RUN ./download_files_for_build.sh
RUN ./create_iso_in_container.sh
CMD ["/bin/bash", "-l"]
