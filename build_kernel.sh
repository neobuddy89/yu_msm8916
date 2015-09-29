#!/bin/bash

###############################################################################
# To all DEV around the world :)                                              #
# to build this kernel you need to be ROOT and to have bash as script loader  #
# do this:                                                                    #
# cd /bin                                                                     #
# rm -f sh                                                                    #
# ln -s bash sh                                                               #
# now go back to kernel folder and run:                                       # 
#                                                         		      #
# sh clean_kernel.sh                                                          #
#                                                                             #
# Now you can build my kernel.                                                #
# using bash will make your life easy. so it's best that way.                 #
# Have fun and update me if something nice can be added to my source.         #
###############################################################################

# Time of build startup
res1=$(date +%s.%N)

if [ "${1}" != "tomato" ]; then
	TARGET="lettuce"
else
	TARGET="tomato"
fi

echo "${bldcya}***** Setting up Environment for $TARGET *****${txtrst}";

. ./env_setup.sh $TARGET || exit 1;
rm -rf $KERNELDIR/out/boot >> /dev/null;
rm -rf $KERNELDIR/out/*.zip >> /dev/null;
rm -f $KERNELDIR/lettuce/ramdisk* >> /dev/null;
rm -f $KERNELDIR/tomato/ramdisk* >> /dev/null;
mkdir -p $KERNELDIR/out/boot;

ramdisk_build() {
	mkdir -p $KERNELDIR/$TARGET;
	# remove previous initramfs files
	if [ -d $INITRAMFS_TMP ]; then
		echo "${bldcya}***** Removing old temp initramfs_source *****${txtrst}";
		rm -rf $INITRAMFS_TMP;
	fi;

	mkdir -p $INITRAMFS_TMP;
	cp -ax $INITRAMFS_SOURCE/* $INITRAMFS_TMP;
	# clear git repository from tmp-initramfs
	if [ -d $INITRAMFS_TMP/.git ]; then
		rm -rf $INITRAMFS_TMP/.git;
	fi;
	
	# remove empty directory placeholders from tmp-initramfs
	find $INITRAMFS_TMP -name EMPTY_DIRECTORY | parallel rm -rf {};

	# remove more from from tmp-initramfs ...
	rm -f $INITRAMFS_TMP/update* >> /dev/null;

	./utilities/mkbootfs $INITRAMFS_TMP | gzip > $KERNELDIR/out/boot/boot.img-ramdisk.gz

	echo "${bldcya}***** Ramdisk Generated for $TARGET *****${txtrst}"
}

ramdisk_build $TARGET

core_build() {
	mkdir -p $KERNELDIR/$TARGET;
	# remove previous files which should regenerate
	rm -f $KERNELDIR/$TARGET/arch/arm64/boot/*.dtb >> /dev/null;
	rm -f $KERNELDIR/$TARGET/arch/arm64/boot/*.cmd >> /dev/null;
	rm -f $KERNELDIR/$TARGET/arch/arm64/boot/Image >> /dev/null;
	rm -f $KERNELDIR/$TARGET/arch/arm64/boot/Image.gz-dtb >> /dev/null;
	rm -f $KERNELDIR/$TARGET/arch/arm64/boot/Image >> /dev/null;
	rm -f $KERNELDIR/$TARGET/Image >> /dev/null;
	rm -f $KERNELDIR/$TARGET/*.img >> /dev/null;

	if [ $TARGET == "tomato" ]; then
		cp $KERNELDIR/arch/arm64/configs/$KERNEL_CONFIG_TOMATO $KERNELDIR/$TARGET/.config;
		make O=$KERNELDIR/$TARGET $KERNEL_CONFIG_TOMATO;
	else
		cp $KERNELDIR/arch/arm64/configs/$KERNEL_CONFIG_LETTUCE $KERNELDIR/$TARGET/.config;
		make O=$KERNELDIR/$TARGET $KERNEL_CONFIG_LETTUCE;
	fi;

	. $KERNELDIR/$TARGET/.config
	GETVER=`grep 'Hydra-Kernel_v.*' $KERNELDIR/$TARGET/.config | sed 's/.*_.//g' | sed 's/".*//g'`
	echo "${bldcya}Building => Hydra ${GETVER} for $TARGET ${txtrst}";
	if [ $USER != "root" ]; then
		make O=$KERNELDIR/$TARGET -j$NUMBEROFCPUS
	else
		nice -n -15 make O=$KERNELDIR/$TARGET -j$NUMBEROFCPUS
	fi;

	if [ ! -e $KERNELDIR/$TARGET/arch/arm64/boot/Image ]; then
		echo "${bldred}Kernel STUCK in BUILD!${txtrst}"
		exit 1;
	fi;

	./utilities/dtbToolCM -2 -o $KERNELDIR/out/boot/dt.img -s 2048 -p $KERNELDIR/$TARGET/scripts/dtc/ $KERNELDIR/$TARGET/arch/arm64/boot/dts/

	# copy all needed to out kernel folder
	cp -f $KERNELDIR/$TARGET/arch/arm64/boot/Image $KERNELDIR/out/boot/Image
}

core_build

if [ -e $KERNELDIR/out/boot/Image ]; then
	echo "${bldcya}***** Final Touch for Kernel *****${txtrst}"
	rm -f $KERNELDIR/out/Hydra*.zip >> /dev/null;
	
	cd $KERNELDIR/out/
	zip -r Hydra_${TARGET}_v${GETVER}-`date +"[%m-%d]-[%H-%M]"`.zip .
	echo "${bldcya}***** Ready to Roar *****${txtrst}";
	# finished? get elapsed time
	res2=$(date +%s.%N)
	echo "${bldgrn}Total time elapsed: ${txtrst}${grn}$(echo "($res2 - $res1) / 60"|bc ) minutes ($(echo "$res2 - $res1"|bc ) seconds) ${txtrst}";	
	while [ "$push_ok" != "y" ] && [ "$push_ok" != "n" ] && [ "$push_ok" != "Y" ] && [ "$push_ok" != "N" ]
	do
	      read -p "${bldblu}Do you want to push the kernel to the sdcard of your device?${txtrst}${blu} (y/n)${txtrst}" push_ok;
		sleep 1;
	done
	if [ "$push_ok" == "y" ] || [ "$push_ok" == "Y" ]; then
		STATUS=`adb get-state` >> /dev/null;
		while [ "$ADB_STATUS" != "device" ]
		do
			sleep 1;
			ADB_STATUS=`adb get-state` >> /dev/null;
		done
		adb push $KERNELDIR/out/Hydra*.zip /storage/sdcard0/
		while [ "$reboot_recovery" != "y" ] && [ "$reboot_recovery" != "n" ] && [ "$reboot_recovery" != "Y" ] && [ "$reboot_recovery" != "N" ]
		do
			read -p "${bldblu}Reboot to recovery?${txtrst}${blu} (y/n)${txtrst}" reboot_recovery;
			sleep 1;
		done
		if [ "$reboot_recovery" == "y" ] || [ "$reboot_recovery" == "Y" ]; then
			adb reboot recovery;
		fi;
	fi;
	exit 0;
else
	echo "${bldred}Kernel STUCK in BUILD!${txtrst}"
	exit 1;
fi;
