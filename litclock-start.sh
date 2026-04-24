# Create the start script on internal filesystem
cat > /usr/local/stuff/bin/litclock-start.sh << 'EOF'
#!/bin/sh
# Wait for SD card to be mounted
for i in $(seq 1 30); do
    mount | grep -q "mmcblk1p1" && break
    sleep 1
done
# Wait for nickel to fully start then kill it
sleep 15
killall nickel 2>/dev/null
killall sickel 2>/dev/null
killall sickel-launcher 2>/dev/null
mount -o remount,rw /mnt/sd
setsid nohup /mnt/sd/litclock.sh > /tmp/litclock.log 2>&1 &
EOF
chmod +x /usr/local/stuff/bin/litclock-start.sh
