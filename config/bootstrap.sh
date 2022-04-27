#!/bin/bash -e

#
# Evironment variables
#
#    CMVERBOSE  : increase verbosity (set any value)
#    CMISO      : official ISO to use (i.e. CentOS-8.1.1911-x86_64-boot.iso)
#    CMOUT      : resultig ISO file name (i.e. CentOS-8.1.1911-x86_64-minimal.iso)
#    CMETH      : dependency resolving method to use (deep or fast)

# Color codes for printing colored output
RESET=`tput sgr0`

COLOR_BLACK=`tput setaf 0`
COLOR_RED=`tput setaf 1`
COLOR_GREEN=`tput setaf 2`
COLOR_YELLOW=`tput setaf 3`
COLOR_BLUE=`tput setaf 4`
COLOR_MAGENTA=`tput setaf 5`
COLOR_CYAN=`tput setaf 6`
COLOR_WHITE=`tput setaf 7`

# Default values
#
# default official ISO to use
iso="CentOS-Stream.iso"
#
# resulting ISO file name and volume label
# such values will be determined again according to source image during ISO unpack
out="CentOS-Stream-Minimal.iso"
lbl="CentOS-Stream-Minimal"
#
# no need to change further

pw="$(pwd)"
dp="${pw}/image"
md="${pw}/mtemp"
bo="${dp}/BaseOS"
ap="${dp}/AppStream"
pr="${dp}/PyRepo"

pm="python.modules"
pmd="$(pwd)/ptemp"
dnir="$(pwd)/dtemp/"
dnddr="$(pwd)/rpms/"

function cmusage() {
   echo "Usage: ${0} <run [force] | clean | debug [package [package ..]] | step ..>"
   echo
   exit 1
}

function cmusagestep() {
   echo "Usage: ${0} step .."
   echo
   echo " Workflow steps:"
   echo "    isounpack"
   echo "    createtemplate"
   echo "    collectrpms"
   echo "    createrepo"
   echo "    createiso"
   echo
   echo " Some usefull functions:"
   echo "    rpmurl <package> [package ..]"
   echo "    rpmdownload <package> [package ..]"
   echo
   exit 1
}

function cmnotcentos() {
   echo
   echo " ! This script is not suitable to use in this platform"
   echo
   exit 1
}

function cmcheck() {
  if [ "${PIPESTATUS[0]}" != "0" ]; then
    exit 1
  fi
}

function cmpipe() {
   while read line; do
      echo "   ${1}${line}"
   done
}

function cmdot() {
   if [ "${CMVERBOSE}" != "" ]; then
      cmpipe
   else
      echo -n "   "
      while read line; do
         echo -n "."
      done
      echo " done"
   fi
}


function cmisounpack() {
   if [ ! -e "${iso}" ]; then
      echo
      echo " ! Reference ISO (${iso}) not found."
      echo
      echo "   You can download CentOS 8 from following resource;"
      echo "   http://isoredirect.centos.org/centos/8/isos/x86_64/"
      echo
      echo "   If you want to use different minor release, please"
      echo "   specify it like below;"
      echo
      echo "   CMISO='/path/to/file.iso' ./bootstrap.sh .."
      echo
      exit 1
   fi
   echo " ${COLOR_GREEN}~ unpacking ISO${RESET} "
   if [ ! -d "${md}" ]; then
      mkdir -p "${md}"
      7z x -y "${iso}" -o"${md}"/ || exit 1
      cmcheck
      echo "   ${md} unpacked"
   fi
}

function cmclean() {
   rm -rf "${dp}"
   rm -rf target_comps.xml "${out}" .[cpmrdtfu]*
}

function cmcreatetemplate() {
   if [ ! -d "${md}" ]; then
      if [ "${CMSTEP}" != "" ]; then
         echo " ! ISO not unpacked, please run;"
         echo "   ${0} step isounpack"
         echo
      fi
      return
   fi
   echo -n " ${COLOR_GREEN}~ Preparing image template${RESET}"
   echo -n "."
   mkdir -p "${dp}"
   mkdir -p "${bo}/Packages"
   mkdir -p "${ap}/Packages"
   echo -n "."
   cp -r "${md}/EFI" "${dp}/"
   cmcheck
   echo -n "."
   
   cp "templ_discinfo" "${dp}/.discinfo"
   cp "templ_media.repo" "${dp}/media.repo"
   cp "ks.cfg" "${dp}/"
   [ -f "${pm}" ] && cut -f1 -d ' ' "${pm}" > "ks_configs/${pm}"
   cp -r "ks_configs" "${dp}/"
   echo -n "."
   cp -r "${md}/isolinux" "${dp}/"
   yes | cp -fr isolinux.cfg "${dp}/isolinux/" 
   echo -n "."
   cp -r "${md}/images" "${dp}/"
   cmcheck
   rm -f "${dp}/.treeinfo"
   touch "${dp}/.treeinfo"
   while IFS=  read line; do
      imgf="$(echo "${line}" | grep "^images/" | awk -F" = " {'print $1'})"
      if [ "${imgf}" != "" ]; then
         if [ ! -e "${dp}/${imgf}" ]; then
            echo
            echo
            echo " ! Image '${imgf}' not found in base ISO"
            echo
            exit 1
         fi
         sum="$(sha256sum "${dp}/${imgf}" | awk {'print $1'})"
         echo "${imgf} = sha256:${sum}" >> "${dp}/.treeinfo"
         echo -n "."
      else
         echo "${line}" >> "${dp}/.treeinfo"
      fi
   done < "templ_treeinfo"
   if [ -e "${md}/.treeinfo" ]; then
      ts="$(cat ${md}/.treeinfo | grep "timestamp = " | head -1 | awk -F"= " {'print $2'} | tr -d "\n\r")"
      if [ "${ts}" != "" ]; then
         sed -i "s/\\(timestamp = \\)[0-9]\\+/\\1${ts}/g" "${dp}/.treeinfo"
      fi
   fi
   if [ -e "${md}/.discinfo" ]; then
      ts="$(head -1 ${md}/.discinfo | tr -d "\n\r")"
      if [ "${ts}" != "" ]; then
         sed -i "s/[0-9]\\+\.[0-9]\\+/${ts}/g" "${dp}/.discinfo"
      fi
   fi
   echo " done"
}

function cmrpmdownload() {
   # input arguments
   # package [package ..]
   if [ "${1}" == "" ]; then
      echo " ! Pacakge name required for rpmdownload"
      echo 
      exit 1
   fi
   mkdir -p rpms
   pkg="$(echo "${@}" | rev | cut -d/ -f1 | cut -d- -f3- | rev)"
   dnf download --arch=noarch,x86_64 --releasever=8 --installroot=${dnir} --resolve --alldeps --destdir=/root/rpms ${pkg} -x \*i686
}

function cmrpmurl() {
   # input arguments
   # package [package ..]
   if [ "${CMSTEP}" != "" -a "${1}" == "" ]; then
      echo "Usage: ${0} step rpmurl <package> [package ..]"
      echo 
      exit 1
   fi
   dnf download -x \*i686 --urls "${@}" | \
      grep "^https" | \
      sort | uniq > "${pw}/.urls"
   
   [ ! -f ${pw}/.urls ] && {
      echo "Not all dependent packages found.  Please fix before proceeding !!"
      echo
      exit 1
   } || true
}

function cmcopyrpmtorepo() {
   # input argument
   # package 
   vb="${CMVERBOSE}"
   if [ "${1}" == "" ]; then
     echo "Usage: ${0} step copyrpmtorepo <package>"
     echo
     exit 1
   fi
   
   rpmpkgname=$(echo ${1} | sed s/\+/%2b/g)
   rpmurl="$(grep Downloading.*://.*${rpmpkgname} ${dnir}var/log/dnf.librepo.log)" 
   
   case $rpmurl in
     *BaseOS*)
       if [ -d "${bo}/Packages" ]; then
         cp "rpms/${1}" "${bo}/Packages/"
         echo "Copied ${COLOR_BLUE}${1}${RESET} to ${COLOR_GREEN}BaseOS${RESET}/Packages/"
       fi
       ;;
     *)
       if [ -d "${ap}/Packages" ]; then
         cp "rpms/${1}" "${ap}/Packages/"
         echo "Copied ${COLOR_BLUE}${1}${RESET} to ${COLOR_YELLOW}AppStream${RESET}/Packages/"
       fi
       ;;
   esac
}

function cmcollectrpms() {
   echo " ${COLOR_GREEN}~ Collecting RPMs for package(s)${RESET}"

   if [ "${CMVERBOSE}" == "" ]; then
      echo -n "   "
   fi
   rm -f .miss .rslv .dler
   mkdir -p rpms
   
   [ -d "rpms.cache" ] && cp rpms.cache/* rpms/ || true

   dnf groupinstall --downloadonly -y --nobest --releasever=8 --installroot=${dnir} --destdir=${dnddr} $(grep "^@" packages.txt | sed "s/^@//") -x \*i686 $(grep "^-" packages.txt | sed "s/^-/-x /") 
   dnf download --arch=noarch,x86_64 --releasever=8 --installroot=${dnir} --resolve --alldeps --destdir=${dnddr} $(grep -v "^#" packages.txt | grep -v "^@" | grep -v "^-") -x \*i686

   echo "$(ls rpms | sort | uniq)" | while read r; do
      if [ -e "rpms/${r}" ]; then
         cmcopyrpmtorepo ${r}
      fi
   done

   if [ "${CMVERBOSE}" == "" ]; then
      echo " done"
   fi
}

function cmcollectpymodules() {
   [ ! -f ${pm} ] && return -1

   echo " ${COLOR_GREEN}~ Collecting Python Modules for package(s)${RESET}"
   if [ "${CMVERBOSE}" == "" ]; then
      echo -n "   "
   fi

   [ ! -d ${pmd} ] && mkdir -p ${pmd}

   pip3 download -d ./ptemp/ pip==21.3.1 
   pip3 download -d ${pmd} -r ${pm}
}

function cmcreaterepo() {
   if [ ! -d "${bo}/Packages" ]; then
      echo " ! Image temmplate is not ready, please run;"
      echo "   ${0} step createtemplate"
      echo "   ${0} step collectrpms"
      echo
      exit 1
   fi

   echo " ${COLOR_GREEN}~ Creating repodata${RESET}"
   cd "${bo}"
   cmcheck
   rm -rf repodata
   cp "${pw}"/base_comps.xml comps.xml
   createrepo_c --workers 8 -g comps.xml . 2>&1 | cmdot
   cmcheck
   cd "${pw}"

   cd "${ap}"
   cmcheck
   rm -rf repodata
   cp "${pw}"/appstream_comps.xml comps.xml
   createrepo_c --workers 8 -g comps.xml . 2>&1 | cmdot
   cmcheck
   cd "${pw}"

   cd "${ap}"
   cp "${pw}"/modules.yaml.xz .
   xz -d modules.yaml.xz
   modifyrepo_c --mdtype=modules modules.yaml repodata/
   cmcheck
   cd "${pw}"

   rm -f "${uc}"

   [ ! -d ${pmd} ] && return 0
   [ ! -d ${pr} ] && mkdir -p ${pr}
   cp -rf ${pmd}/* ${pr}/
}

function cmcreateiso() {
   if [ ! -d "${bo}/repodata" ]; then
      echo " ${COLOR_RED}! Repo is not ready, please run;${RESET}"
      echo "   ${0} step createrepo"
      echo
      exit 1
   fi

   lbl="$(cat "${dp}/isolinux/isolinux.cfg" | grep "LABEL=" | awk -F"LABEL=" {'print $2'} | awk {'print $1'} | grep -v "^$" | head -1 | tr -d "\n\r")"
   if [ "${CMOUT}" == "" ]; then
      out="CentOS-x86_64-minimal.iso"
   fi
   echo " ${COLOR_GREEN}~ Creating ISO image${RESET}"
   cd "${dp}"
   chmod 664 isolinux/isolinux.bin
   rm -f "${pw}/${out}"
   mkisofs \
      -input-charset utf-8 \
      -o "${pw}/${out}" \
      -b isolinux/isolinux.bin \
      -c isolinux/boot.cat \
      -no-emul-boot \
      -V "${lbl}" \
      -boot-load-size 4 \
      -boot-info-table \
      -eltorito-alt-boot \
      -e images/efiboot.img \
      -no-emul-boot \
      -R -J -v -T . 2>&1 | cmdot
      cmcheck
   if [ -e "/usr/bin/isohybrid" ]; then
      echo " ${COLOR_GREEN}~ ISO hybrid${RESET}"
      isohybrid --uefi "${pw}/${out}" | cmdot
      cmcheck
   fi
   if [ -e "/usr/bin/implantisomd5" ]; then
      echo " ${COLOR_GREEN}~ Implant ISO MD5${RESET}"
      implantisomd5 --force --supported-iso "${pw}/${out}" | cmdot
      cmcheck
   fi
   cd "${pw}"
   isz="$(du -h "${out}" | awk {'print $1'})"
   echo " ${COLOR_GREEN}~ ISO image ready: ${COLOR_MAGENTA}${out}${RESET} (${COLOR_YELLOW}${isz}${RESET})"
}

function cmjobfull() {
   cmclean
   cmisounpack
   cmcreatetemplate
   cmcollectrpms
   cmcollectpymodules
   collectpymodules
   cmcreaterepo
   cmcreateiso
}

function cmjobquick() {
   if [ "${CMISO}" != "" ]; then
      cmisounpack
   fi
   cmcreatetemplate
   cmcreaterepo
   cmcreateiso
}

if [ ! -e /etc/centos-release ]; then
   cmnotcentos
fi
if [ "$(cat /etc/centos-release | grep "CentOS Linux release 8\|CentOS Stream release 8")" == "" ]; then
   cmnotcentos
fi
if [ ! -e "/usr/bin/repoquery" -o ! -e "/usr/bin/createrepo" -o ! -e "/usr/bin/yumdownloader" -o ! -e "/usr/bin/curl" -o ! -e "/usr/bin/mkisofs" ]; then
   echo
   echo " ! Some additional packages needs to be installed."
   echo "   Please run following command to have them all:"
   echo
   echo "   dnf -y install yum-utils createrepo syslinux genisoimage isomd5sum bzip2 curl file"
   echo
   exit 1
fi
if [ "${CMISO}" != "" ]; then
   iso="${CMISO}"
fi
if [ "${CMOUT}" != "" ]; then
   out="${CMOUT}"
fi
if [ ! -e "packages.txt" ]; then
   touch "packages.txt"
fi

if [ "${1}" == "run" ]; then
   shift
   if [ "${1}" == "force" ]; then
      cmjobfull
   elif [ -d "${bo}/Packages" ]; then
      cmjobquick
   else
      cmjobfull
   fi
elif [ "${1}" == "clean" ]; then
   cmclean
elif [ "${1}" == "debug" ]; then
   shift
   if [ "${1}" == "" ]; then
      cmusage
   fi
   cmjobsingle "${@}"
elif [ "${1}" == "step" ]; then
   shift
   if [ "${1}" == "" ]; then
      cmusagestep
   fi
   cmd="cm${1}"
   shift
   CMVERBOSE=1 CMSTEP=1 ${cmd} "${@}"
else
   cmusage
fi

