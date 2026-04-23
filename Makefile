SHELL := bash
ifeq ($(SSH_KEY),)
	SSH_KEY = ~/.ssh/id_rsa.pub
endif

all: help

help:
	@echo "build            - build base image"

build:
	genesis build -i $(SSH_KEY) -f .
