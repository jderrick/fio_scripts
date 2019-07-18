nvme_ctrl=0
nvme_ns=1

engine=libaio
runtime=300
filename=/dev/nvme${nvme_ctrl}n${nvme_ns}
percentile_list=1.0:25.0:50.0:75.0:90.0:99.0:99.9:99.99:99.999:99.9999:99.99999:99.999999:100.0
cpus_allowed=
numjobs=0

# Can be passed-in
bs=${bs:-4k}
iodepth=${iodepth:-64}
rw=${rw:-randread}
name=${name:+_$name}


# Validate and discover interrupt affinities
[ -b $filename ] || exit 1

output=$(awk -v pattern="nvme${nvme_ctrl}q" '$0~pattern {
	gsub(":","")
	gsub("\n","")

	irq=$1
	name=$NF

	"cat /proc/irq/"irq"/smp_affinity_list" | getline smp
	"cat /proc/irq/"irq"/effective_affinity_list" | getline eff
	"cat /proc/irq/"irq"/node" | getline node

	printf "irq[%s]: %s: affinity[%s] effective[%s] node[%u]\n",
		irq, name, smp, eff, node
}' /proc/interrupts | column -t)

while read line; do
	if [[ "$line" == *"nvme${nvme_ctrl}q0"* ]]; then
		continue
	fi

	if [[ "$numjobs" -gt 0 ]]; then
		cpus_allowed="${cpus_allowed},"
	fi

	cpus_allowed="${cpus_allowed}$(echo $line | sed 's/.*effective\[\([0-9]\+\)\].*/\1/')"
	numjobs=$((numjobs + 1))
done <<< $output

runname=${rw}_${engine}_${bs}_qd${iodepth}_${numjobs}j${name}
mkdir -p logs/${runname}
logprefix=logs/${runname}/${runname}
runlog=${logprefix}_run.log

command="fio \
--ioengine=${engine} \
--direct=1 \
--buffered=0 \
--size=100% \
--time_based \
--norandommap \
--ramp_time=0 \
--refill_buffers \
--log_avg_msec=1000 \
--log_max_value=1 \
--group_reporting \
--percentile_list=${percentile_list} \
--filename=${filename} \
--name=${runname} \
--stonewall \
--bs=${bs} \
--rw=${rw} \
--iodepth=${iodepth} \
--cpus_allowed=${cpus_allowed} \
--numjobs=${numjobs} \
--runtime=${runtime} \
--write_bw_log=${logprefix} \
--write_iops_log=${logprefix} \
--write_lat_log=${logprefix}"

echo "Logging to $runlog"
echo -e "$output\n" > $runlog
echo "Command:" >> $runlog
echo -e "${command// / '\\''\n'}\n" | tee -a $runlog
echo "One Line:" >> $runlog
echo -e "$command\n" >> $runlog
$command | tee -a $runlog
