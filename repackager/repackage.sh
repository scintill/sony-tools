#!/bin/bash
echo "Processing $2 file:$1"
rm -rf zip_out
rm bm_native_$2.zip
rm bm_loop_$2.zip

unzip -q $1 -d zip_out
cp -a zip_out/META-INF zip_out/META-INF-SRC
mv zip_out/META-INF zip_out/META-INF-NATIVE

# process boot logo!
cd zip_out
if [ -f boot.img ] ; then kernel_img="boot.img"; fi
if [ -f zImage ] ; then kernel_img="zImage"; fi
if [ -f *.elf ]; then kernel_img=`ls *.elf`; fi

if [ $kernel_img ] ; then 
    echo "kernel '$kernel_img' found"
    ../prebuilt/sksplit $kernel_img
    mv $kernel_img original_kernel.img
    mv sec0-* zimage
    mv sec1-* initramfs.src.gz
    rm -rf sec2*
    # unpack cpio
    mkdir cpio
    cd cpio
    cat ../initramfs.src.gz | gzip -d | cpio -i --make-directories
    chown -R root:root .

    is_doomlord="0"
    if [ -x init_ics ]; then
	echo "Doomlord type recovery"
	is_doomlord="1"
	rm -r *~ 
	rm init_gb init init.sh recovery.rc
	mv init_ics init
	cd sbin
	ln -s ../init ueventd
	cd ..
	cp -a cpio cpio_native
    fi
    if [ -f sbin/ramdisk.cpio ]; then
	echo "New FXP recovery"
	cd ..
	mkdir cpio_native
	cd cpio_native
	cat ../cpio/sbin/ramdisk.cpio | cpio -i --make-directories
	chown -R root:root .	
	cd ..
    else
	echo "Old FXP recovery"
	cd ..
	cp -a cpio cpio_native
    fi
    cd cpio_native

    # cleanup cwm and unused stuff
    rm -r res recovery.fstab
    cd sbin
    rm e2fsck fix_permissions mke2fs nandroid-md5.sh parted sdparted tune2fs fota-mke2fs  fota-ua mr autoroot.sh checkabortedflash 
    grep chargemon bootrec*
    shouldadd_chargemon="$?"
    echo result:$shouldadd_chargemon
    rm bootrec bootrec-device bootrec-device-fs 
    cd ..
    if [ "$shouldadd_chargemon" == "0" ]; then
	echo "-----> should add chargemon ($shouldadd_chargemon)"
	# replace bootrec by chargemon
	echo should replace bootrec by chargemon
	sed 's,^.*sbin/bootrec,    exec /system/bin/chargemon,g' init.semc.rc > init.semc.rc.tmp
    else
	# kill bootrec
	sed 's,^.*sbin/bootrec,# /sbin/bootrec,g' init.semc.rc > init.semc.rc.tmp
    fi
    mv init.semc.rc.tmp init.semc.rc

    # ro.secure=0
    sed 's,ro.secure.*=.*1,ro.secure=0,g' default.prop > default.prop.tmp
    mv default.prop.tmp default.prop

    # native is done
    find . | cpio -o -H newc | gzip > ../initramfs.native.gz    

    # prepare cpio_loop and cpio_alt
    cd ..
    cp -a cpio_native cpio_loop 
    cp -a cpio_native cpio_alt
    
    # alt first
    cd cpio_alt
    # patch fstab.semc if it exists
    if [ -f fstab.semc ]; then
	sed 's,/dev/block/mmcblk0p12,/dev/block/mmcblk0p16,g' fstab.semc > fstab.semc.tmp
	mv fstab.semc.tmp fstab.semc
	sed 's,/dev/block/mmcblk0p13,/dev/block/mmcblk0p17,g' fstab.semc > fstab.semc.tmp
	mv fstab.semc.tmp fstab.semc
	sed 's,/dev/block/mmcblk0p14,/dev/block/mmcblk0p18,g' fstab.semc > fstab.semc.tmp
	mv fstab.semc.tmp fstab.semc
	sed 's:ro,:rw,:g' fstab.semc > fstab.semc.tmp
	mv fstab.semc.tmp fstab.semc
    fi
    # same for init.semc.fs.rc (cm9)
    if [ -f init.semc.fs.rc ]; then
	sed 's,/dev/block/mmcblk0p12,/dev/block/mmcblk0p16,g' init.semc.fs.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.fs.rc
	sed 's,/dev/block/mmcblk0p13,/dev/block/mmcblk0p17,g' init.semc.fs.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.fs.rc
	sed 's,/dev/block/mmcblk0p14,/dev/block/mmcblk0p18,g' init.semc.fs.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.fs.rc
    fi
    # finish with init.semc.rc
    sed 's,/dev/block/mmcblk0p12,/dev/block/mmcblk0p16,g' init.semc.rc > init.semc.rc.tmp
    mv init.semc.rc.tmp init.semc.rc
    sed 's,/dev/block/mmcblk0p13,/dev/block/mmcblk0p17,g' init.semc.rc > init.semc.rc.tmp
    mv init.semc.rc.tmp init.semc.rc
    sed 's,/dev/block/mmcblk0p14,/dev/block/mmcblk0p18,g' init.semc.rc > init.semc.rc.tmp
    mv init.semc.rc.tmp init.semc.rc
    find . | cpio -o -H newc | gzip > ../initramfs.alt.gz    
    cd ..

    # now loop
    cd cpio_loop
    cp  ../../prebuilt/losetup-static sbin/
    chmod 755 sbin/losetup-static
    # loop patches, first identify cpio type
    if [ -f fstab.semc ]; then
	# cm10 style cpio
	echo "CM10/AOKP JB cpio"
	# prepare loopbacks
	sed '/on fs/ a\
    mkdir /sd\
    wait /dev/block/mmcblk0p15\
    mount vfat /dev/block/mmcblk0p15 /sd\
    exec /sbin/losetup-static /dev/block/loop2 /sd/custom_system.ext4\
    exec /sbin/losetup-static /dev/block/loop3 /sd/custom_cache.ext4\
    exec /sbin/losetup-static /dev/block/loop4 /sd/custom_data.ext4' init.semc.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.rc

	# patch fstab.semc
	sed 's,/dev/block/mmcblk0p12,/dev/block/loop2,g' fstab.semc > fstab.semc.tmp
	mv fstab.semc.tmp fstab.semc
	sed 's,/dev/block/mmcblk0p13,/dev/block/loop3,g' fstab.semc > fstab.semc.tmp
	mv fstab.semc.tmp fstab.semc
	sed 's,/dev/block/mmcblk0p14,/dev/block/loop4,g' fstab.semc > fstab.semc.tmp
	mv fstab.semc.tmp fstab.semc
	sed 's:ro,:rw,:g' fstab.semc > fstab.semc.tmp
	mv fstab.semc.tmp fstab.semc
    else if [ -f init.semc.fs.rc ]; then
	echo "CM9 type recovery"
	# prepare loopbacks
	sed '/on fs/ a\
    mkdir /sd\
    wait /dev/block/mmcblk0p15\
    mount vfat /dev/block/mmcblk0p15 /sd\
    exec /sbin/losetup-static /dev/block/loop2 /sd/custom_system.ext4\
    exec /sbin/losetup-static /dev/block/loop3 /sd/custom_cache.ext4\
    exec /sbin/losetup-static /dev/block/loop4 /sd/custom_data.ext4' init.semc.fs.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.fs.rc

	# replace all partitions
	echo "Patching partitions in init.semc.fs.rc, pwd="`pwd`
	sed 's,/dev/block/mmcblk0p12,/dev/block/loop2,g' init.semc.fs.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.fs.rc
	sed 's,/dev/block/mmcblk0p13,/dev/block/loop3,g' init.semc.fs.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.fs.rc
	sed 's,/dev/block/mmcblk0p14,/dev/block/loop4,g' init.semc.fs.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.fs.rc
	sed 's, ro , rw ,g' init.semc.fs.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.fs.semc.rc
	echo "Patching partitions done"


    else if [ $is_doomlord == "1" ]; then
	echo "Doomlord cpio"
	# prepare loopbacks
	sed '/on fs/ a\
    mkdir /sd\
    wait /dev/block/mmcblk0p15\
    mount vfat /dev/block/mmcblk0p15 /sd\
    exec /sbin/losetup-static /dev/block/loop2 /sd/custom_system.ext4\
    exec /sbin/losetup-static /dev/block/loop3 /sd/custom_cache.ext4\
    exec /sbin/losetup-static /dev/block/loop4 /sd/custom_data.ext4' init.semc.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.rc

	# replace all partitions
	sed 's,/dev/block/mmcblk0p12,/dev/block/loop2,g' init.semc.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.rc
	sed 's,/dev/block/mmcblk0p13,/dev/block/loop3,g' init.semc.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.rc
	sed 's,/dev/block/mmcblk0p14,/dev/block/loop4,g' init.semc.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.rc
	sed 's,remount ro,remount rw,g' init.semc.rc > init.semc.rc.tmp
	mv init.semc.rc.tmp init.semc.rc
    else
	echo "CM9 / ICS cpio"
    fi # is doomlord
    fi # is cm9
    fi # is cm10

    # repackage cpio
    find . | cpio -o -H newc | gzip > ../initramfs.loop.gz
    cd ..
fi

# aroma nova kernel
if [ -f customize/kernel/kernel.elf ]; then
    sksplit customize/kernel/kernel.elf
    mv sec0-* zimage_custo
    rm sec1-* sec2-*
fi


cp -a META-INF-NATIVE META-INF-LOOP
cp -a META-INF-NATIVE META-INF-ALT

# patch installer zip

# KERNELS
# native
# aokp/cm style kernels:
sed 's:package_extract_file("boot.img", "/dev/block/mmcblk0p3");:package_extract_file("zimage", "/tmp/zimage");\
package_extract_file("initramfs.native.gz",  "/tmp/initramfs.cpio.gz");\
run_program("/sbin/kf", "1", "/tmp/zimage", "/tmp/initramfs.cpio.gz");\
run_program("/sbin/sync");:g' META-INF-NATIVE/com/google/android/updater-script > new_script
mv new_script META-INF-NATIVE/com/google/android/updater-script

# KA style kernels:
sed 's:package_extract_file("zImage", "/tmp/zImage"),:package_extract_file("zimage", "/tmp/zimage"),package_extract_file("initramfs.native.gz", "/tmp/initramfs.cpio.gz"),:g' META-INF-NATIVE/com/google/android/updater-script > new_script
mv new_script META-INF-NATIVE/com/google/android/updater-script
sed 's:write_raw_image("/tmp/zImage", "/dev/block/mmcblk0p3"),:run_program("/sbin/kf", "1", "/tmp/zimage", "/tmp/initramfs.cpio.gz"),:g' META-INF-NATIVE/com/google/android/updater-script > new_script
mv new_script META-INF-NATIVE/com/google/android/updater-script
sed 's:delete("/tmp/zImage"):delete("/tmp/zimage"),delete("/tmp/initramfs.cpio.gz"):g' META-INF-NATIVE/com/google/android/updater-script > new_script
mv new_script META-INF-NATIVE/com/google/android/updater-script

# Nova kernel
sed 's:run_program("/sbin/dd", "if=/dev/zero", "of=/dev/block/mmcblk0p3");::g' META-INF-NATIVE/com/google/android/updater-script > new_script
mv new_script META-INF-NATIVE/com/google/android/updater-script
sed 's:package_extract_file("kernel.elf", "/dev/block/mmcblk0p3");:package_extract_file("zimage", "/tmp/zimage");\
package_extract_file("initramfs.native.gz",  "/tmp/initramfs.cpio.gz");\
run_program("/sbin/kf", "1", "/tmp/zimage", "/tmp/initramfs.cpio.gz");\
run_program("/sbin/sync");:g' META-INF-NATIVE/com/google/android/updater-script > new_script
mv new_script META-INF-NATIVE/com/google/android/updater-script

# Nova rom / Aroma kernels:
sed 's:package_extract_file("customize/kernel/kernel.elf", "/dev/block/mmcblk0p3");:package_extract_file("zimage_custo", "/tmp/zimage");\
package_extract_file("initramfs.native.gz",  "/tmp/initramfs.cpio.gz");\
run_program("/sbin/kf", "1", "/tmp/zimage", "/tmp/initramfs.cpio.gz");\
run_program("/sbin/sync");:g' META-INF-NATIVE/com/google/android/updater-script > new_script
mv new_script META-INF-NATIVE/com/google/android/updater-script


# loop
# aokp/cm style kernels:
sed 's:package_extract_file("boot.img", "/dev/block/mmcblk0p3");:package_extract_file("zimage", "/tmp/zimage");\
package_extract_file("initramfs.loop.gz",  "/tmp/initramfs.cpio.gz");\
run_program("/sbin/kf", "2", "/tmp/zimage", "/tmp/initramfs.cpio.gz");\
run_program("/sbin/sync");:g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script

# KA style kernels:
sed 's:package_extract_file("zImage", "/tmp/zImage"),:package_extract_file("zimage", "/tmp/zimage"),package_extract_file("initramfs.loop.gz", "/tmp/initramfs.cpio.gz"),:g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script
sed 's:write_raw_image("/tmp/zImage", "/dev/block/mmcblk0p3"),:run_program("/sbin/kf", "2", "/tmp/zimage", "/tmp/initramfs.cpio.gz"),:g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script
sed 's:delete("/tmp/zImage"):delete("/tmp/zimage"),delete("/tmp/initramfs.cpio.gz"):g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script

# Nova kernel
sed 's:run_program("/sbin/dd", "if=/dev/zero", "of=/dev/block/mmcblk0p3");::g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script
sed 's:package_extract_file("kernel.elf", "/dev/block/mmcblk0p3");:package_extract_file("zimage", "/tmp/zimage");\
package_extract_file("initramfs.loop.gz",  "/tmp/initramfs.cpio.gz");\
run_program("/sbin/kf", "2", "/tmp/zimage", "/tmp/initramfs.cpio.gz");\
run_program("/sbin/sync");:g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script

# Nova rom / Aroma kernels:
sed 's:package_extract_file("customize/kernel/kernel.elf", "/dev/block/mmcblk0p3");:package_extract_file("zimage_custo", "/tmp/zimage");\
package_extract_file("initramfs.loop.gz",  "/tmp/initramfs.cpio.gz");\
run_program("/sbin/kf", "2", "/tmp/zimage", "/tmp/initramfs.cpio.gz");\
run_program("/sbin/sync");:g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script

# alt
# aokp/cm style kernels:
sed 's:package_extract_file("boot.img", "/dev/block/mmcblk0p3");:package_extract_file("zimage", "/tmp/zimage");\
package_extract_file("initramfs.alt.gz",  "/tmp/initramfs.cpio.gz");\
run_program("/sbin/kf", "2", "/tmp/zimage", "/tmp/initramfs.cpio.gz");:g' META-INF-ALT/com/google/android/updater-script > new_script
mv new_script META-INF-ALT/com/google/android/updater-script

# KA style kernels:
sed 's:package_extract_file("zImage", "/tmp/zImage"),:package_extract_file("zimage", "/tmp/zimage"),package_extract_file("initramfs.alt.gz", "/tmp/initramfs.cpio.gz"),:g' META-INF-ALT/com/google/android/updater-script > new_script
mv new_script META-INF-ALT/com/google/android/updater-script
sed 's:write_raw_image("/tmp/zImage", "/dev/block/mmcblk0p3"),:run_program("/sbin/kf", "2", "/tmp/zimage", "/tmp/initramfs.cpio.gz"),:g' META-INF-ALT/com/google/android/updater-script > new_script
mv new_script META-INF-ALT/com/google/android/updater-script
sed 's:delete("/tmp/zImage"):delete("/tmp/zimage"),delete("/tmp/initramfs.cpio.gz"):g' META-INF-ALT/com/google/android/updater-script > new_script
mv new_script META-INF-ALT/com/google/android/updater-script

# Nova rom / Aroma kernels:
sed 's:package_extract_file("customize/kernel/kernel.elf", "/dev/block/mmcblk0p3");:package_extract_file("zimage_custo", "/tmp/zimage");\
package_extract_file("initramfs.alt.gz",  "/tmp/initramfs.cpio.gz");\
run_program("/sbin/kf", "2", "/tmp/zimage", "/tmp/initramfs.cpio.gz");\
run_program("/sbin/sync");:g' META-INF-ALT/com/google/android/updater-script > new_script
mv new_script META-INF-ALT/com/google/android/updater-script


# PARTITIONS
# loop partitions
sed 's:/dev/block/mmcblk0p12:/dev/block/loop2:g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script
sed 's:/dev/block/mmcblk0p13:/dev/block/loop3:g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script
sed 's:/dev/block/mmcblk0p14:/dev/block/loop4:g' META-INF-LOOP/com/google/android/updater-script > new_script
mv new_script META-INF-LOOP/com/google/android/updater-script

# alt partitions
sed 's:/dev/block/mmcblk0p12:/dev/block/mmcblk0p16:g' META-INF-ALT/com/google/android/updater-script > new_script
mv new_script META-INF-ALT/com/google/android/updater-script
sed 's:/dev/block/mmcblk0p13:/dev/block/mmcblk0p17:g' META-INF-ALT/com/google/android/updater-script > new_script
mv new_script META-INF-ALT/com/google/android/updater-script
sed 's:/dev/block/mmcblk0p14:/dev/block/mmcblk0p18:g' META-INF-ALT/com/google/android/updater-script > new_script
mv new_script META-INF-ALT/com/google/android/updater-script

# replace Aroma with my build 
if [ -f META-INF-NATIVE/com/google/android/aroma-config ]; then
    echo "Replacing Aroma with my build"
    cp ../prebuilt/update-binary  META-INF-NATIVE/com/google/android/
    cp ../prebuilt/update-binary  META-INF-LOOP/com/google/android/
    cp ../prebuilt/update-binary  META-INF-ALT/com/google/android/
fi

# Zips
customize=""
if [ -d customize ] ; then customize="customize" ; fi

mv META-INF-NATIVE META-INF
zip -q -r ../bm_native_$2.zip META-INF system $customize zimage initramfs.native.gz zimage_custo
mv META-INF META-INF-NATIVE

mv META-INF-LOOP META-INF
zip -q -r ../bm_loop_$2.zip META-INF system $customize zimage initramfs.loop.gz zimage_custo
mv META-INF META-INF-LOOP

mv META-INF-ALT META-INF
zip -q -r ../bm_alt_$2.zip META-INF system $customize zimage initramfs.alt.gz zimage_custo
mv META-INF META-INF-ALT
