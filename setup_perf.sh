echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
	echo performance > $i
done
