#!/bin/bash

# Convenience script to create the Alpine container from the Windows/Linux host.
# The assignment's manual Docker command can still be used instead.

if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker is not installed or is not available in PATH"
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -qx 'myserver'; then
    echo "A container named myserver already exists."
    echo "Remove it first with: docker rm -f myserver"
    exit 1
fi

if ! docker image inspect alpine >/dev/null 2>&1; then
    echo "Downloading Alpine image..."
    docker pull alpine || exit 1
fi

echo "Creating myserver container..."
docker run -dit --name myserver -p 1234:1234 alpine sh || exit 1

echo "Installing required packages..."
docker cp setup_alpine.sh myserver:/root/setup_alpine.sh || exit 1
docker exec myserver sh /root/setup_alpine.sh || exit 1

echo "Copying Assignment 2 files..."
docker cp server.sh myserver:/root/server.sh || exit 1
docker cp plot_population.py myserver:/root/plot_population.py || exit 1

echo
echo "Container is ready."
echo "Open a shell with: docker exec -it myserver sh"
echo "Then run: cd /root && bash server.sh"
