#!/bin/bash
# This script must be executable by root
DEVICE_PATH="$1"
MAJOR_NUMBER="$2"
MINOR_NUMBER="$3"

# USB identifiers of the device
VENDOR_ID="$4"
PRODUCT_ID="$5"

CONTAINER_NAME="scanservjs"
IMAGE_NAME="sbs20/scanservjs:v3.0.3"

logger "Scanner ($VENDOR_ID:$PRODUCT_ID) is available at $DEVICE_PATH. Let's make it available to the scan server container"

# Is the container running already?
logger "Is the container running already?"
container_id=$(docker ps -q -f name=$CONTAINER_NAME)
if [ -z "$container_id" ]; then
  logger "Container was not running. We should start it, with the right device ID"
  # echo 'c $MAJOR_NUMBER:* rwm' > /sys/fs/cgroup/devices/docker/$container_id*/devices.allow
  # Container was not running. We should start it, with the right device ID
  bus_nb=$(lsusb | grep "04c5:132b" | grep -o -E "Bus [0-9]+" | grep -o -E "[0-9]+")
  bus_nb=${bus_nb%$'\n'}
  device_nb=$(lsusb | grep "$VENDOR_ID:$PRODUCT_ID" | grep -o -E "Device [0-9]+" | grep -o -E "[0-9]+")
  device_nb=${device_nb%$'\n'}

  if [ -z "$device_nb" ]; then
    logger "Unable to find where this device is connected. Ignoring."
    exit 1
  fi
  logger "Waiting for Docker to be available (if the scanner is plugged when the host boots, udev will trigger this script before Docker is even started)"
  # Waiting for Docker to be available (if the scanner is plugged when the host boots, udev will trigger this script before Docker is even started)
  attempts=0
  while true ; do
    if [ "$(systemctl is-active docker)" == "active" ]; then
      break
    fi
    logger "sleep 10"
    sleep 10
    attempts=$(( attempts + 1 ))
    if [ "$attempts" -gt 10 ]; then
      logger "Docker is not running. Will not start scan server."
      exit 1
    fi
  done

  logger "Starting the scan server from $IMAGE_NAME, with device $device_nb ($VENDOR_ID:$PRODUCT_ID, major number is $MAJOR_NUMBER)..."
  # --device adds the existing device to the container.
  # --device-cgroup-rule makes it possible to add future hot-plugged devices
  # see https://docs.docker.com/engine/reference/commandline/run/#device-cgroup-rule
  docker run --detach \
    --rm \
    --publish 8080:8080 \
    --volume /var/run/dbus:/var/run/dbus \
    --volume /srv/docker/scanservjs/output:/var/lib/scanservjs/output \
    --volume /srv/docker/scanservjs/config:/etc/scanservjs \
    --name "$CONTAINER_NAME" \
    --device=/dev/bus/usb/"$bus_nb"/"$device_nb":/dev/bus/usb/"$bus_nb"/"$device_nb" \
    --device-cgroup-rule="c $MAJOR_NUMBER:* rmw" \
    --privileged \
    "$IMAGE_NAME" 2>&1 | logger
else
  logger "Container is running. We just have to add the device there"
  # Container is running. We just have to add the device there
  logger "Adding the new scanner to the scan server container..."
  docker exec "$CONTAINER_NAME" mknod "/dev/$DEVICE_PATH" c "$MAJOR_NUMBER" "$MINOR_NUMBER" 2>&1 | logger
fi
