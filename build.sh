#!/bin/bash

cd /root/StubHubScraper
git pull origin main
. ./set_env_variables.sh
python3 main.py
