for bs in 512 4k 8k 16k 32k 64k 128k; do
	echo "..."
	sleep 5
	echo "Starting $bs run"
	bs=$bs ./run.sh
done
