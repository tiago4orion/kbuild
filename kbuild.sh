#!/usr/bin/env nash

WORKDIR  = $NASHPATH+"/lib/kbuild/workdir"
BUILDDIR = $WORKDIR+"/build"
TMPDIR   = $WORKDIR+"/tmp"

_, _     <= mkdir -p $BUILDDIR $TMPDIR

fn download(version) {
	kfname    = "linux-"+$version+".tar.xz"
	ktgzpath  = $TMPDIR+"/"+$kfname
	linuxURL  = "https://cdn.kernel.org/pub/linux/kernel/v4.x"

	_, status <= test -f $ktgzpath

	if $status != "0" {
		wget -c $linuxURL+"/linux-"+$version+".tar.xz" -O $ktgzpath
	}

	return $ktgzpath
}

fn prepare_config(kbuilddir, name, config) {
	oldpwd <= pwd

	chdir($kbuilddir)

	make clean
	make mrproper

	if $config == "" {
		_, status <= test -f /proc/config.gz

		if $status != "0" {
			printf "There's no config to use..."

			exit("1")
		}

		rm -f .config
		zcat /proc/config.gz > .config

		# send ENTER to every prompt of new/deprecated opt
		yes "" | make oldconfig

		sedReplace = "s/LOCALVERSION=.*/LOCALVERSION="+$name+"/g"

		cat .config | sed $sedReplace > .config2

		cp .config2 .config
	} else {
		rm -f .config

		cat $config | sed $sedReplace > .config
	}

	chdir($oldpwd)
}

fn build(kbuilddir) {
	oldpwd <= pwd

	chdir($kbuilddir)

	yes "" | make olddefconfig

	make -j2

	chdir($oldpwd)
}

fn install(kbuilddir, version) {
	canonName <= echo -n $version | sed "s/\\.//g"

	chdir($kbuilddir)

	# install modules
	sudo make modules_install
	sudo cp -v arch/x86_64/boot/bzImage "/boot/vmlinuz-linux"+$canonName

	replaceKver = "s/-linux/-linux"+$canonName+"/g"

	sudo cat "/etc/mkinitcpio.d/linux.preset" | sed $replaceKver > /tmp/preset.tmp

	sudo cp /tmp/preset.tmp "/etc/mkinitcpio.d/linux"+$canonName+".preset"
	sudo mkinitcpio -k $version -c /etc/mkinitcpio.conf -g "/boot/initramfs-linux"+$canonName+".img"
	sudo cp -v System.map "/boot/System.map-linux"+$canonName
	sudo ln -sf "/boot/System.map-linux"+$canonName "/boot/System.map"
	sudo grub-mkconfig -o /boot/grub/grub.cfg
	echo "Installation finished."
}

fn kbuild(name, version, config) {
	oldpwd    <= pwd
	ktgzpath  <= download($version)

	kbuilddir = $BUILDDIR+"/linux-"+$version

	_, _      <= rm -rf $kbuilddir

	tar xvf $ktgzpath -C $BUILDDIR

	prepare_config($kbuilddir, $name, $config)
	build($kbuilddir)
	install($kbuilddir, $version)
	chdir($oldpwd)
}
