# centos-8-minimal

A pure bash script to create **minimal installation ISO** image together with **additional packages**, leveraging one of official CentOS 8 ISO distribution.

This will create an ISO image in the order of workflow shown below:

1. Rerefence ISO will be mounted (to "mtemp/" in working folder).
2. An ISO template will be created (to "image/" in working folder).
    - Essentials (isolinux, EFI, boot images etc) will be copied from reference ISO as it is.
    - Template files will be re-constructed and (re)placed on ISO template.
3. Dependencies for "core" and "additional" packages will be scanned and a resulting package list will be created.
    - Required packages (RPM files) will be downloaded in this phase if it is not downloaded yet and will be added into ISO template.
    - A copy of newly downloaded RPM file will be added into "rpms/" in working folder for later use to avoid re-downloading.
4. A repository (and metadata information) will be created under ISO template to use packages added.
5. ISO image will be created using ISO template that prepared in above steps.
6. Reference ISO will be unmounted.

Hence, there are two main parts of this project:

- Script itself and template files as essentials (**bootstrap.sh** and templ\_\* files explained in Footnotes section)
- An additional package list to install during OS installation (**packages.txt**).

### Requirements

- CentOS 8

  You can run script on CentOS 8 only (since it depends on CentOS 8 utilities).
    
- Some additional packages needs to be installed in order to run the script. Those can be installed by using the command below:

        yum -y install yum-utils createrepo syslinux genisoimage isomd5sum bzip2 curl file

- One of the official ISO image of CentOS 8 distribution. Place it to same folder with the script.

        CentOS-8.X.XXXX-x86_64-boot.iso
        CentOS-8.X.XXXX-x86_64-dvd1.iso

### Synopsis

Basic usage of the script:

    # ./bootstrap.sh 
    Usage: ./bootstrap.sh <run [force] | clean | debug [package [package ..]] | step ..>

Alternative usage for each step (in same workflow order) and usage for some functions:

    # ./bootstrap.sh step
    Usage: ./bootstrap.sh step ..

    Workflow steps:
        isomount
        createtemplate
        scandeps
        createrepo
        createiso
        isounmount

    Some usefull functions:
        rpmname <package> [package ..]
        rpmurl <package> [package ..]
        rpmdownload <package> [package ..]
        fulldeps <package>

### Usage

You can change the content of "packages.txt" if you wish and then simply run following command:

    # ./bootstrap.sh run

Script will continue to use the ISO template resource (image/) created at the first run on consequent runs. If you did changes on anywhere, you should "force" it to start job from the scratch by issuing following command;

    # ./bootstrap.sh run force
    
Above command is actually equal to following two commands:

    # ./bootstrap.sh clean
    # ./bootstrap.sh run

The "clean" switch will do "isounmount" when necessary and will clean ISO template and temporary files created by the script.

You can run particular workflow-step manually when needed. For example:

    # ./bootstrap.sh step createiso
    
There are also some functions which will not do any effect on working data. 

For example you can get download links for given package(s):

     # ./bootstrap.sh step rpmurl httpd php 
 
Or, you can download RPM files directly by issuing;

    # ./bootstrap.sh step rpmdownload httpd php

Dowloaded RPM files will be placed into "rpms/" folder for later use (will not be added into ISO template).

If you want to add custom package(s) into the resulting ISO and you want it to be installed during OS installation, you can add package name(s) into **packages.txt** file. For example;

**packages.txt**:

    # Some networking tools
    net-tools
    ethtool
    tcpdump

    # Some system tools
    pciutils

    # Apache - PHP related
    httpd
    mod_security
    mod_ssl
    php
    php-mbstring
    php-soap

(Empty lines and lines starting with "#" will be ignored.)

If you want to download package(s) together with it's full dependencies you can use "debug" main switch. This switch is also useful to track processing of given package(s) when something went wrong.

    # ./bootstrap.sh debug php

This "debug" switch will create verbose output.
Again, dowloaded RPM files will be placed into "rpms/" folder for later use (and will not be added into ISO template).

### Environent Variables

- **CMVERBOSE**=\<any value\>

   It is possible to have verbose output by using this variable with any value. For example;
   
        # CMVERBOSE=1 ./bootstrap.sh run force

   It is not set by default (no verbose output).
         
- **CMISO**="referece iso filename"

   You can specify the reference ISO to be used with this variable like;
   
        # CMISO="CentOS-8.1.1911-x86_64-boot.iso" ./bootstrap.sh run force

   Script will use "CentOS-8.1.1911-x86\_64-boot.iso" by default if such variable is not given.
- **CMOUT**="resulting iso filename"

   You can specify the name of resulting ISO file. For example;
   
        # CMOUT="my-minimal-centos-8.iso" ./bootstrap.sh run force    
- **CMETH**=\<**fast** \| **deep**\>

   The "method" that will be used while resolving package dependencies. You can combine it with *CMVERBOSE* for debugging purposes.

   The script will use "fast" method by default. This will use system utilities to resolve dependencies (by issuing "repoquery --requires --resolve --recursive <package>") and will use what it returns as the list of packages.

   The "deep" method is a kind of custom implementation of dependency resolving process. It is really slow since it checks each package recursively with its dependencies. But, it will give an idea about the dependency resolving process and it may also useful for debugging if something went wrong.
   
   On the other hand, you can use "deep" method with "debug" switch together to do debugging on single package. For example;
   
        # CMETH="deep" ./bootstrap.sh debug php
    
   Above command will display each package checks recursively and will display a dependency tree when it finish resolving.

### Footnotes

- Group file template

   The list of "core" packages which defined in "templ\_comps.xml" template file is obtained from the "BaseOS" group on official CentOS 8 DVD-ISO.
   
   First, its content will be used to collect required installation packages. Then, the list of packages specified in "package.txt" will be merged into it and will be used as group file to include in metadata of the resulting ISO.
   
   You can change such file if you want, but please keep a single empty line inside the "packagelist" of group "core" to merge additional packages defined in package.txt like;


        <group>
           <id>core</id>
           <name>Core</name>
           <packagelist>
              <packagereq type="optional">tboot</packagereq>
        --- put single empty line here. ---
           </packagelist>
        </group>
   
- Other Template files

   The template file "tepl\_treeinfo" is obtained from official CentOS 8 DVD-ISO (".treeinfo" is the original name) . It's content will be re-constructed according to the reference ISO you are going to use and the resulting file will be added into ISO template.
   
   Other template files (templ\_discinfo, templ\_media.repo) are obtained from official CentOS 8 DVD-ISO and they will be added into resulting ISO as it is.
   
   
