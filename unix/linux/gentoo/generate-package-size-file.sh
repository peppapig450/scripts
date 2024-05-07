#!/bin/sh
qsize -b -C -q | grep -vP "^(app-alternatives/|virtual/)" > "$1"
