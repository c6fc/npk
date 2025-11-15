#! /bin/bash -x

shutdown_on_exit() {
	echo "[!] Script exited. Shutting down in two minutes."
	shutdown +2
}

trap shutdown_on_exit EXIT
set -e

# amazon-linux-extras install -y epel
yum install -y wget p7zip pv

mkfs.ext4 /dev/nvme1n1

if [[ -e /dev/nvme2n1 ]]; then
	mkfs.ext4 /dev/nvme2n1
	mkdir -p /npk/raw
	mkdir /npk/compressed

	mount /dev/nvme1n1 /npk/raw	
	mount /dev/nvme2n1 /npk/compressed
else
	mkdir /npk
	mount /dev/nvme1n1 /npk

	mkdir /npk/{raw,compressed}
fi

export TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
export AWS_DEFAULT_REGION=`wget "--header=X-aws-ec2-metadata-token: $TOKEN" -qO- http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//'`
export AWS_DEFAULT_OUTPUT=json

export TARGETFILE={{targetfile}}
export TARGETFILETYPE={{targetfiletype}}
if [[ `echo $TARGETFILE | grep s3: | wc -l` -gt 0 ]]; then
	aws s3 cp $TARGETFILE /npk/raw/rawfile
else
	wget $targetfile -O /npk/raw/rawfile
fi

ls -alh /npk/raw/rawfile
FILETYPE=`file -b /npk/raw/rawfile`
FILENAME=`echo ${TARGETFILE##*/} | cut -d"?" -f1`

if [[ `echo $FILETYPE | grep text | wc -l` -eq 0 ]]; then
	echo "[+] File is compressed. Attempting to decompress"
	7za l /npk/raw/rawfile

	mv /npk/raw/rawfile /npk/raw/cprfile
	FIRSTFILE=`7za l /npk/raw/cprfile | tail -n 3 | head -n 1 | awk ' { print($6) } '`
	FILENAME=${FIRSTFILE##*/}
	7za x -bsp1 /npk/raw/cprfile -o/npk/raw/output/
	# rm -f /npk/raw/cprfile
	mv /npk/raw/output/$FILENAME /npk/raw/rawfile
fi

echo [+] Counting lines in file...
FILELINES=$(wc -l /npk/raw/rawfile | cut -d" " -f1)
SIZE=$(ls -al /npk/raw/rawfile | cut -d" " -f5)

# echo "Compressing with 7z"
# 7za a /npk/compressed/$FILENAME.7z /npk/raw/rawfile

echo "Compressing with gzip"
pv -nte /npk/raw/rawfile | gzip -c  > /npk/compressed/$FILENAME.gz

echo "$FILENAME has $FILELINES lines and $SIZE bytes. Preparing to upload as $TARGETFILETYPE."

aws s3 cp /npk/compressed/$FILENAME.gz s3://{{dictionarybucket}}/$TARGETFILETYPE/$FILENAME.gz --metadata type=$TARGETFILETYPE,lines=$FILELINES,size=$SIZE

if [[ `echo $TARGETFILE | grep s3: | wc -l` -gt 0 ]]; then
	aws s3 rm $TARGETFILE
fi