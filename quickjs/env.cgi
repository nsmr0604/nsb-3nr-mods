#!/bin/sh
echo "Content-Type: text/plain"
echo ""
env | grep -E 'REQUEST|QUERY|HTTP_|GATEWAY|SERVER_' | sort
